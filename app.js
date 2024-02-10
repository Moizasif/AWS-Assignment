'use strict';

const express = require('express')
const app = express();

const port = 5000;
const host = '0.0.0.0';

app.get('/', (req, res) => {
  res.send('Hello World from Moiz!');
})

app.listen(port, host);
console.log(`Running on http://${host}:${port}`);
