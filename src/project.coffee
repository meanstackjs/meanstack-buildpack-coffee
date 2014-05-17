path = require 'path'
fs = require 'fs'

module.exports = (projectdir, grunt, mean) ->
  mean.npmtasks = [
    'grunt-contrib-copy',
    'grunt-contrib-coffee',
    'grunt-contrib-watch',
    'grunt-contrib-uglify',
    'grunt-contrib-clean',
    'grunt-contrib-less',
    'grunt-contrib-cssmin',
    'grunt-contrib-htmlmin',
    'grunt-coffeelint',
    'grunt-text-replace',
    'grunt-easyassets',
    'grunt-angular-templates',
    'grunt-nodemon',
    'grunt-concurrent',
    'grunt-vhosted'
  ]

  mean.watch = (grunt, mean, action, filepath, target) ->
    if target is 'easyassets'
      mean.config.assets = grunt.file.readJSON 'assets.json'

    if target is 'server-coffee'
      mean.config.coffeelint.server = filepath

    else if target is 'angular-coffee'
      mean.config.coffeelint.angular = filepath
      mean.config.coffee['angular-development'].src = path.relative \
        mean.config.coffee['angular-development'].cwd, filepath
      mean.config.copy['angular-coffee'].files[0].src = path.relative \
        mean.config.copy['angular-coffee'].files[0].cwd, filepath
      mapfilepath = path.join 'public/js/',
        path.relative('src/client/', filepath).replace('.coffee', '.js.map')
      mean.config.replace['sourcemaps'].src = mapfilepath

    else if target is 'angular-views'
      mean.config.copy['angular-views'].files[0].src = path.relative \
        mean.config.copy['angular-views'].files[0].cwd, filepath

    else if target is 'less'
      mean.config.less['assets'].src = path.relative \
        mean.config.less['assets'].cwd, filepath

    else if target is 'assets'
      mean.config.copy['assets'].files[0].src = path.relative \
        mean.config.copy['assets'].files[0].cwd, filepath

    if action is 'added' or action is 'deleted' or target is 'easyassets'
      fs.writeFileSync '.tmp/restart', 'restart'

  return mean
