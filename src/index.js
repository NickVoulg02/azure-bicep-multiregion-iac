const http = require('http');

const server = http.createServer((req, res) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/html');
    
    // Grabbing the region from Azure's built-in environment variables
    const region = process.env.REGION_NAME || 'Local Environment';

    const htmlResponse = `
        <html>
            <body style="font-family: Arial, sans-serif; text-align: center; margin-top: 50px;">
                <h1>Welcome to ToyHR! 🚀</h1>
                <p>This application was successfully deployed via Azure Bicep.</p>
                <p><strong>Running in Region:</strong> ${region}</p>
            </body>
        </html>
    `;
    
    res.end(htmlResponse);
});

// Azure App Service injects the port automatically via the PORT environment variable
const port = process.env.PORT || 8080;
server.listen(port, () => {
    console.log(`Server running on port ${port}`);
});