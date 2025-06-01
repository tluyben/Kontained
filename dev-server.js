const express = require('express');
const { createServer } = require('vite');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

// Command line arguments
const dbPath = process.argv[2];
const port = process.argv[3] || 3000;

// Initialize SQLite database
const db = new sqlite3.Database(dbPath);

// Create Express app
const app = express();

// Create Vite dev server
async function createViteServer() {
  const vite = await createServer({
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
  app.use('*', async (req, res) => {
    try {
      // Read index.html
      let template = fs.readFileSync(
        path.resolve(process.cwd(), 'index.html'),
        'utf-8'
      );

      // Apply Vite HTML transforms
      template = await vite.transformIndexHtml(req.originalUrl, template);

      // Send the transformed HTML
      res.status(200).set({ 'Content-Type': 'text/html' }).end(template);
    } catch (e) {
      vite.ssrFixStacktrace(e);
      console.error(e);
      res.status(500).end(e.message);
    }
  });
}

// Start the server
async function startServer() {
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