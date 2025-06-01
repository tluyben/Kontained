import express, { Request, Response } from 'express';
import { createServer, ViteDevServer } from 'vite';
import sqlite3 from 'sqlite3';
import path from 'path';
import fs from 'fs';
import { execSync } from 'child_process';

// Command line arguments
const dbPath: string = process.argv[2];
const port: number = parseInt(process.argv[3] || '3000', 10);

// Initialize SQLite database
const db: sqlite3.Database = new sqlite3.Database(dbPath);

// Create Express app
const app: express.Application = express();

// Create Vite dev server
async function createViteServer(): Promise<void> {
  const vite: ViteDevServer = await createServer({
    server: {
      middlewareMode: true,
      hmr: {
        port: 24678
      }
    },
    appType: 'custom',
    root: process.cwd(),
    optimizeDeps: {
      force: true
    }
  });

  // Use vite's connect instance as middleware
  app.use(vite.middlewares);

  // Handle all other routes
  app.use('*', async (req: Request, res: Response) => {
    try {
      // Read index.html
      let template: string = fs.readFileSync(
        path.resolve(process.cwd(), 'index.html'),
        'utf-8'
      );

      // Apply Vite HTML transforms
      template = await vite.transformIndexHtml(req.originalUrl, template);

      // Send the transformed HTML
      res.status(200).set({ 'Content-Type': 'text/html' }).end(template);
    } catch (e: any) {
      vite.ssrFixStacktrace(e);
      console.error(e);
      res.status(500).end(e.message);
    }
  });
}

// Start the server
async function startServer(): Promise<void> {
  try {
    await createViteServer();
    
    app.listen(port, () => {
      console.log(`🚀 Dev server running at http://localhost:${port}`);
      console.log('✨ Hot Module Replacement (HMR) enabled');
      console.log('📝 Edit files and see changes instantly');
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down dev server...');
  db.close();
  process.exit(0);
});

// Start the server
startServer(); 