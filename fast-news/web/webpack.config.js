var webpack = require('webpack');
var path = require('path');

var BUILD_DIR = path.resolve(__dirname, 'app');
var APP_DIR = path.resolve(__dirname, 'src');

var config = {
  entry: APP_DIR + '/index.jsx',
  output: {
    path: BUILD_DIR,
    filename: 'bundle.js'
  },
  module: {
     loaders : [
       {
         test : /\.jsx?/,
         include : APP_DIR,
         loader : 'babel'
       },
	   {
         test: /\.less$/,
         loader: "style!css!less"
       }
     ]
   }
};

module.exports = config;