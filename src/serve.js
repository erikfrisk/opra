var fs = require('fs');
var url = require('url');
var path = require('path');
var _ = require('underscore');

_.mixin(require('underscore.string').exports());

exports.serveConstructor = function(dependencies) {
  return function(rootpath, settings) {
    settings = settings || {};

    if (_.isUndefined(settings.assetRoot)) {
      settings.assetRoot = rootpath;
    }

    return function(req, res, next) {
      var pathname = url.parse(req.url).pathname;
      var filepath = path.join(rootpath, pathname);

      fs.stat(filepath, function(err, stat) {
        if (err) {
          dependencies.log("OPRA ERROR (while searching for " + filepath + ")", err);
          next();
          return;
        }

        if (stat.isDirectory()) {
          pathname = path.join(pathname, 'index.html');
          filepath = path.join(filepath, 'index.html');
        }

        if (!_.endsWith(pathname, '.html')) {
          next();
          return;
        }

        dependencies.build(filepath, settings, function(err, result) {
          if (err) {
            dependencies.log("OPRA ERROR while compiling " + pathname, err);
            next();
            return;
          }
          res.setHeader('Content-Type', 'text/html');
          res.setHeader('Content-Length', Buffer.byteLength(result));
          res.end(result);
        });
      });
    };
  };
};