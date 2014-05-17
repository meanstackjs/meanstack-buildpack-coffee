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
    'grunt-angular-templates'
  ]

  grunt.task.registerTask 'update-assets', 'Updates assets.', ->
    stat = fs.statSync('../../assets.json')
    fs.utimesSync('../../assets.json', stat.atime, new Date())

  mean.watch = (grunt, mean, action, filepath, target) ->
    if target is 'easyassets'
      grunt.config.set 'assets', grunt.file.readJSON 'assets.json'

    coffeeConfig = grunt.config 'coffee'
    copyConfig = grunt.config 'copy'
    replaceConfig = grunt.config 'replace'
    coffeelintConfig = grunt.config 'coffeelint'
    lessConfig = grunt.config 'less'

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

      # Copy to project
      file = path.resolve \
        mean.config.copy['angular-coffee'].files[0].dest, mean.config.copy['angular-coffee'].files[0].src.replace('.coffee', '.*')
      mean.config.copy['plugins'].files[0].src = path.relative \
        mean.config.copy['plugins'].files[0].cwd, file

    else if target is 'angular-views'
      mean.config.copy['angular-views'].files[0].src = path.relative \
        mean.config.copy['angular-views'].files[0].cwd, filepath

      # Copy to project
      file = path.resolve \
        mean.config.copy['angular-views'].files[0].dest, mean.config.copy['angular-views'].files[0].src
      mean.config.copy['plugins'].files[0].src = path.relative \
        mean.config.copy['plugins'].files[0].cwd, file

    else if target is 'less'
      mean.config.less['assets'].src = path.relative \
        mean.config.less['assets'].cwd, filepath

      # Copy to project
      file = path.resolve \
        mean.config.less['assets'].dest, mean.config.less['assets'].src.replace('.less', mean.config.less['assets'].ext)
      mean.config.copy['plugins'].files[0].src = path.relative \
        mean.config.copy['plugins'].files[0].cwd, file

    else if target is 'assets'
      mean.config.copy['assets'].files[0].src = path.relative \
        mean.config.copy['assets'].files[0].cwd, filepath

      # Copy to project
      file = path.resolve \
        mean.config.copy['assets'].files[0].dest, mean.config.copy['assets'].files[0].src
      mean.config.copy['plugins'].files[0].src = path.relative \
        mean.config.copy['plugins'].files[0].cwd, file

    if action is 'added' or action is 'deleted' or target is 'easyassets' or target is 'server-coffee'
      if target isnt 'easyassets'
        stat = fs.statSync('../../assets.json')
        fs.utimesSync('../../assets.json', stat.atime, new Date())
      else
        fs.writeFileSync '../../.tmp/restart', 'restart'
    else
      fs.writeFileSync '../../.tmp/reload', 'reload'

  delete mean.tasks.preview
  delete mean.config.watch.nodemon
  delete mean.config.coffee.other.files['server.js']
  delete mean.config.coffee.other.files['vhosts.js']

  mean.config.easyassets.options.prefix = 'public/plugins/<%= pkg.name %>/'
  mean.config.ngtemplates[mean.config.pkg.name.replace '-', '.'].options.prefix = 'public/plugins/<%= pkg.name %>/'
  mean.config.less.assets.options.paths[1] = '../../public/vendor/'
  mean.config.clean.plugins = ['../../public/plugins/<%= pkg.name %>/']
  mean.config.copy.plugins =
    files: [
      expand: true
      cwd: 'public/'
      src: '**/*.*'
      dest: '../../public/plugins/<%= pkg.name %>/'
    ]

  # Modify watch config
  mean.config.watch['server-views'].options.livereload = false
  mean.config.watch['angular-coffee'].options.livereload = false
  mean.config.watch['angular-coffee'].tasks.push 'copy:plugins'
  mean.config.watch['angular-views'].options.livereload = false
  mean.config.watch['angular-views'].tasks.push 'copy:plugins'
  mean.config.watch['less'].options.livereload = false
  mean.config.watch['less'].tasks.push 'copy:plugins'
  mean.config.watch['assets'].options.livereload = false
  mean.config.watch['assets'].tasks.push 'copy:plugins'

  # Modify install task
  mean.tasks.install.splice(mean.tasks.install.indexOf('clean:release') + 1, 0, 'clean:plugins')
  mean.tasks.install.splice(mean.tasks.install.indexOf('vhosted'), 1)
  mean.tasks.install.splice(mean.tasks.install.indexOf('clean:plugins') + 1, 0, 'update-assets')
  mean.tasks.install.splice(mean.tasks.install.indexOf('clean:plugins') + 1, 0, 'copy:plugins')

  # Modify develop task
  mean.tasks.develop.splice(mean.tasks.develop.indexOf('concurrent:development'), 1, 'clean:plugins')
  mean.tasks.develop.splice(mean.tasks.develop.indexOf('clean:plugins') + 1, 0, 'watch')
  mean.tasks.develop.splice(mean.tasks.develop.indexOf('clean:plugins') + 1, 0, 'update-assets')
  mean.tasks.develop.splice(mean.tasks.develop.indexOf('clean:plugins') + 1, 0, 'copy:plugins')

  # Register integrate task
  grunt.registerTask 'integrate', ['clean:plugins', 'copy:plugins', 'update-assets']

  # Protect againts app integration
  protect = ->
    grunt.log.writeln 'No MEAN Stack host app found, skipping integration.'
    mean.config.less.assets.options.paths.splice(1, 1)
    mean.tasks.install.splice(mean.tasks.install.indexOf('clean:update-assets'), 1)
    mean.tasks.install.splice(mean.tasks.install.indexOf('clean:plugins'), 1)
    mean.tasks.install.splice(mean.tasks.install.indexOf('copy:plugins'), 1)
    mean.tasks.develop.splice(mean.tasks.develop.indexOf('clean:update-assets'), 1)
    mean.tasks.develop.splice(mean.tasks.develop.indexOf('clean:plugins'), 1)
    mean.tasks.develop.splice(mean.tasks.develop.indexOf('copy:plugins'), 1)
    mean.tasks.develop.splice(mean.tasks.develop.indexOf('watch'), 1)
    grunt.registerTask 'integrate', []
  if fs.existsSync '../../package.json'
    pkg = grunt.file.readJSON('../../package.json')
    if not pkg.mean?
      protect()
  else
    protect()

  return mean
