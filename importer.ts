import * as fs from 'fs/promises';
import * as path from 'path';
import * as sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import { createHash } from 'crypto';

interface FileInfo {
  path: string;
  content: Buffer;
  isBinary: boolean;
  hash: string;
}

async function importProject(projectPath: string, dbPath: string): Promise<void> {
  console.log('📁 Importing project to SQLite...');
  
  // Create database
  const db = await open({
    filename: dbPath,
    driver: sqlite3.Database
  });
  
  // Create tables
  await db.exec(`
    CREATE TABLE IF NOT EXISTS files (
      path TEXT PRIMARY KEY,
      content BLOB,
      is_binary BOOLEAN,
      hash TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE TABLE IF NOT EXISTS project_info (
      key TEXT PRIMARY KEY,
      value TEXT,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);
  
  // Read package.json
  const packageJsonPath = path.join(projectPath, 'package.json');
  let packageJson: any;
  
  try {
    const packageJsonContent = await fs.readFile(packageJsonPath, 'utf-8');
    packageJson = JSON.parse(packageJsonContent);
    
    // Store package.json info
    await db.run(
      'INSERT OR REPLACE INTO project_info (key, value) VALUES (?, ?)',
      ['package.json', packageJsonContent]
    );
  } catch (err) {
    console.error('❌ Failed to read package.json:', err);
    throw err;
  }
  
  // Walk project directory
  const files: FileInfo[] = [];
  
  async function walkDir(dir: string, baseDir: string) {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      const relativePath = path.relative(baseDir, fullPath);
      
      // Skip node_modules, .git, etc.
      if (entry.name === 'node_modules' || entry.name === '.git' || entry.name.startsWith('.')) {
        continue;
      }
      
      if (entry.isDirectory()) {
        await walkDir(fullPath, baseDir);
      } else {
        try {
          const content = await fs.readFile(fullPath);
          const isBinary = !content.toString('utf-8').match(/^[\x00-\x7F]*$/);
          const hash = createHash('sha256').update(content).digest('hex');
          
          files.push({
            path: relativePath,
            content,
            isBinary,
            hash
          });
        } catch (err) {
          console.warn(`⚠️  Failed to read ${relativePath}:`, err);
        }
      }
    }
  }
  
  await walkDir(projectPath, projectPath);
  
  // Import files to database
  console.log(`📦 Importing ${files.length} files...`);
  
  const stmt = await db.prepare(`
    INSERT OR REPLACE INTO files (path, content, is_binary, hash)
    VALUES (?, ?, ?, ?)
  `);
  
  for (const file of files) {
    await stmt.run(file.path, file.content, file.isBinary, file.hash);
  }
  
  await stmt.finalize();
  
  // Store project metadata
  await db.run(
    'INSERT OR REPLACE INTO project_info (key, value) VALUES (?, ?)',
    ['project_name', packageJson.name]
  );
  
  await db.run(
    'INSERT OR REPLACE INTO project_info (key, value) VALUES (?, ?)',
    ['version', packageJson.version]
  );
  
  await db.close();
  
  console.log('✅ Project imported successfully!');
}

// CLI interface
if (require.main === module) {
  const [projectPath, dbPath] = process.argv.slice(2);
  
  if (!projectPath || !dbPath) {
    console.log(`
📁 Project Importer

Usage: node importer.js <project-path> <db-path>

Arguments:
  project-path    Path to your React/TypeScript project
  db-path         Path to create SQLite database

Example:
  node importer.js ./my-shadcn-app ./project.db
`);
    process.exit(1);
  }
  
  importProject(projectPath, dbPath).catch(err => {
    console.error('❌ Import failed:', err);
    process.exit(1);
  });
}

export { importProject }; 