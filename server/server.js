const express = require('express')
const path = require("path");
const serveStatic = require("serve-static");

const app = express()
const port = 3000

app.get('/api', (req, res) => {
  res.send('Hello api')
})



/*
 * Serve Static Files
 */
const staticPath = path.join(__dirname, "dist");
app.use("/", serveStatic(staticPath))



app.listen(port, () => {
  console.log(`App listening on port ${port}`)
})

