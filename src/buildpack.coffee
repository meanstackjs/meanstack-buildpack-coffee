path = require 'path'
fs = require 'fs'
glob = require 'glob'
tinylr = require('tiny-lr')()
request = require 'request'

module.exports = (projectDir, grunt, master) ->
  reldir = path.relative(__dirname, projectDir)

  changed = ['.tmp/reload']

  # Path to master
  if master?
    master = path.relative(projectDir, path.resolve(master))
  else
    master = '../..'

  # Create tmp dir
  if not fs.existsSync "#{projectDir}/.tmp"
    fs.mkdirSync "#{projectDir}/.tmp"
  fs.writeFileSync '.tmp/reload', 'reload'
  fs.writeFileSync '.tmp/restart', 'restart'

  if fs.existsSync "#{master}/package.json"
    slave = true
  else
    slave = false

  grunt.task.registerTask 'restart-nodemon', 'Restarts nodemon.', ->
    if slave
      fs.writeFileSync "#{master}/.tmp/restart", 'restart'
    else
      fs.writeFileSync '.tmp/restart', 'restart'

  grunt.task.registerTask 'reload-browser', 'Reloads browser.', ->
    if slave
      fs.writeFileSync "#{master}/.tmp/reload", 'reload'

  grunt.task.registerTask 'reload-assets', 'Reloads assets.', ->
    grunt.task.run ['read-assets', 'easyassets:parse', 'restart-nodemon']

  grunt.task.registerTask 'livereload', 'Livereloads browser.', ->
    if not slave
      request.post("http://localhost:#{buildpack.livereload}/changed", body: JSON.stringify(files: changed))

  grunt.task.registerTask 'less-config', 'Configures less task.', ->
    files = grunt.file.expand 'src/assets/**/*.less'
    for file in files
        cfg = {}
        cfg.files = {}
        src = 'public/' + buildpack.config.pkg.name + '/' +  path.relative('src/assets', file)
        dest = src.replace('.less', '.css')
        cfg.files[dest] = src
        cfg.options = {}
        cfg.options.sourceMap = true
        cfg.options.ieCompat = true
        cfg.options.sourceMapFilename = dest + '.map'
        cfg.options.sourceMapBasepath = ''
        cfg.options.sourceMapRootpath = '/'
        buildpack.config.less[file] = cfg
      if files.length is 0
        buildpack.config.less['empty'] = {}

  buildpack = {}

  buildpack.livereload = tinylr.options.port

  buildpack.npmtasks = [
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

  buildpack.tasks = {}

  buildpack.tasks.default = ['install']

  buildpack.tasks.init = ['clean:init']

  buildpack.tasks.develop = [
    'clean:build',
    'less-config',
    'read-assets',
    'copy:assets',
    'copy:server-views',
    'copy:angular-views',
    'less',
    'coffeelint:server',
    'coffee:server',
    'coffeelint:angular',
    'coffee:angular',
    'copy:angular-coffee',
    'replace',
    'easyassets:parse',
    'concurrent:development'
  ]

  buildpack.tasks.debug = [
    'clean:build',
    'less-config',
    'read-assets',
    'copy:assets',
    'copy:server-views',
    'copy:angular-views',
    'less',
    'coffeelint:server',
    'coffee:server',
    'coffeelint:angular',
    'coffee:angular',
    'copy:angular-coffee',
    'replace',
    'easyassets:parse',
    'concurrent:debug'
  ]

  buildpack.tasks.preview = [
    'clean:build',
    'less-config',
    'read-assets',
    'copy:assets',
    'copy:server-views',
    'htmlmin',
    'less',
    'easyassets:version-css',
    'cssmin',
    'coffeelint:server',
    'coffee:server',
    'coffeelint:angular',
    'coffee:angular',
    'copy:angular-coffee',
    'replace',
    'ngtemplates',
    'easyassets:version-js',
    'uglify:production',
    'easyassets:version-other',
    'copy:easyassets-other',
    'easyassets:replace',
    'nodemon:production'
  ]

  buildpack.tasks.install = [
    'vhosted',
    'clean:build',
    'less-config',
    'read-assets',
    'copy:assets',
    'copy:server-views',
    'htmlmin',
    'less',
    'easyassets:version-css',
    'cssmin',
    'coffeelint:server',
    'coffee:server',
    'coffeelint:angular',
    'coffee:angular',
    'copy:angular-coffee',
    'replace',
    'ngtemplates',
    'easyassets:version-js',
    'uglify:production',
    'easyassets:version-other',
    'copy:easyassets-other',
    'easyassets:replace'
  ]

  # Build
  buildpack.build = () ->
    config = buildpack.config
    tasks = buildpack.tasks
    grunt.initConfig buildpack.config

    # Load NPM tasks
    grunt.file.setBase path.resolve(__dirname, '../')
    for npmtask in buildpack.npmtasks
      grunt.loadNpmTasks npmtask
    grunt.file.setBase projectDir

    grunt.registerTask 'read-assets', 'Loads asset config.', ->
      buildpack.config.assets = grunt.file.readJSON "#{projectDir}/src/assets/assets.json"

    grunt.registerTask 'default', tasks.default
    grunt.registerTask 'init', tasks.init
    grunt.registerTask 'develop', ->
      if slave
        tasks.develop.splice tasks.develop.indexOf('concurrent:development'), 1
        tasks.develop.push 'watch'
      else
        tinylr.listen buildpack.livereload, (err) ->
          if err
            grunt.fail.warn err
      grunt.task.run tasks.develop
    grunt.registerTask 'debug', ->
      tinylr.listen buildpack.livereload, (err) ->
        if err
          grunt.fail.warn err
      grunt.task.run tasks.debug
    grunt.registerTask 'preview', tasks.preview
    grunt.registerTask 'install', tasks.install
    grunt.event.on 'watch', (action, filepath, target) ->
      buildpack.watch grunt, buildpack, action, filepath, target

  # Config
  buildpack.config =
    pkg: grunt.file.readJSON 'package.json'
    concurrent:
      'development':
        tasks: ['nodemon:development', 'watch']
        options:
          logConcurrentOutput: true
      'debug':
        tasks: ['nodemon:debug', 'watch']
        options:
          logConcurrentOutput: true
      'production':
        tasks: ['nodemon:production']
        options:
          logConcurrentOutput: true
    nodemon:
      'development':
        script: 'server.coffee'
        options:
          watch: ['.tmp/restart']
          delay: 0
          cwd: projectDir
          env:
            NODE_ENV: 'development'
            PORT: '3000'
          callback: (nodemon) ->
            nodemon.on 'log', (event) ->
              console.log event.colour
      'debug':
        script: 'server.coffee'
        options:
          watch: ['.tmp/restart']
          nodeArgs: ['--nodejs', '--debug']
          delay: 0
          cwd: projectDir
          env:
            NODE_ENV: 'development'
            PORT: '3000'
          callback: (nodemon) ->
            nodemon.on 'log', (event) ->
              console.log event.colour
      'production':
        script: 'server.js'
        options:
          watch: ['!']
          delay: 0
          cwd: projectDir
          env:
            NODE_ENV: 'production'
            PORT: '3000'
    watch:
      'server':
        files: ['src/server/**/*']
        options:
          spawn: false
          livereload: false
      'client':
        files: ['src/client/**/*']
        options:
          spawn: false
          livereload: false
      'assets':
        files: ['src/assets/**/*', '!src/assets/assets.json']
        options:
          spawn: false
          livereload: false
      'easyassets':
        files: ['src/assets/assets.json']
        tasks: ['reload-assets']
        options:
          spawn: false
          livereload: false
      'reload':
        files: ['.tmp/reload']
        tasks: ['livereload']
        options:
          spawn: false
          livereload: false
    coffee:
      'server':
        options:
          bare: true
        expand: true
        cwd: 'src/server/'
        src: ['**/*.coffee']
        dest: 'lib/server/'
        ext: '.js'
      'angular':
        options:
          bare: false
          sourceMap: true
        expand: true
        cwd: 'src/client/'
        src: ['**/*.coffee']
        dest: 'public/<%= pkg.name %>/js/'
        ext: '.js'
    coffeelint:
      options:
        'max_line_length':
          level: 'ignore'
      'server': ['src/server/**/*.coffee']
      'angular': ['src/client/**/*.coffee']
    copy:
      'server-views':
        files: [
          expand: true
          cwd: 'src/server/'
          src: ['**/*.*', '!**/*.coffee']
          dest: 'lib/server/'
        ]
      'angular-coffee':
        files: [
          expand: true
          cwd: 'src/client/'
          src: '**/*.coffee'
          dest: 'public/<%= pkg.name %>/js/'
        ]
      'angular-views':
        files: [
          expand: true
          cwd: 'src/client/'
          src: '**/*.html'
          dest: 'public/<%= pkg.name %>/js/'
        ]
      'assets':
        files: [
          expand: true
          cwd: 'src/assets/'
          src: ['**/*.*', '!assets.json']
          dest: 'public/<%= pkg.name %>/'
        ]
      'easyassets-other':
        files: '<%= assets.other %>'
    clean:
      options:
        force: true
      'init': [
        'lib/',
        'public/',
        '.tmp/'
      ]
      'build': [
        'lib/',
        'public/<%= pkg.name %>/**/*',
        '!public/<%= pkg.name %>/vendor/**',
        '!public/<%= pkg.name %>/other/**'
      ]
      'release': [
        'public/<%= pkg.name %>/**/*',
        '!public/<%= pkg.name %>/*.*',
        '!public/<%= pkg.name %>/release/**',
        '!public/<%= pkg.name %>/vendor/**',
        '!public/<%= pkg.name %>/other/**'
      ]
    uglify:
      options:
        mangle:
          except: ['jQuery']
      'production':
        options:
          compress:
            drop_console: true
        files: '<%= assets.js %>'
    replace:
      'sourcemaps':
        src: ['public/<%= pkg.name %>/js/**/*.js.map']
        overwrite: true
        replacements: [
          from: /\s*.*?sourceRoot.*?\,/g
          to: ''
        ]
    less: {}
    cssmin:
      'easyassets':
        files: '<%= assets.css %>'
    htmlmin:
      'production':
        options:
          collapseBooleanAttributes: true
          collapseWhitespace: true
          removeAttributeQuotes: true
          removeComments: true
          removeEmptyAttributes: true
          removeRedundantAttributes: true
          removeScriptTypeAttributes: true
          removeStyleLinkTypeAttributes: true
        files: [
          expand: true
          cwd: 'src/client/'
          src: '**/*.html'
          dest: 'public/<%= pkg.name %>/js/'
        ]
    easyassets:
      options:
        dumpvar: 'assets'
      'version-js':
        assets: '<%= assets %>'
        parse: false
        options:
          version: 'js'
          hashlength: 10
      'version-css':
        assets: '<%= assets %>'
        parse: false
        options:
          version: 'css'
          hashlength: 10
      'version-other':
        assets: '<%= assets %>'
        parse: false
        options:
          version: 'other'
          hashlength: 10
      'replace':
        assets: '<%= assets %>'
        parse: true
        options:
          debug: false
          dumpfile: 'public/<%= pkg.name %>/assets.json'
          ignore: []
          replace: [
            ignore: ['public/<%= pkg.name %>/vendor/**/*']
            src: 'other'
            dest: ['css']
          ]
      'parse':
        assets: '<%= assets %>'
        parse: true
        options:
          debug: true
          dumpfile: 'public/<%= pkg.name %>/assets.json'
    vhosted:
      vhosts:
        patterns: [
          'vhosts/*/package.json',
          'plugins/*/package.json'
        ]

  name = buildpack.config.pkg.name.replace '-', '.'
  buildpack.config.ngtemplates = {}
  buildpack.config.ngtemplates[name] = {}
  buildpack.config.ngtemplates[name] =
    options:
      prefix: 'public/<%= pkg.name %>/js/'
    cwd: 'public/<%= pkg.name %>/js/'
    src: '**/*.html'
    dest: 'public/<%= pkg.name %>/js/partials.js'

  buildpack.watch = (grunt, buildpack, action, filepath, target) ->
    changed = ['.tmp/reload']
    if action isnt 'deleted' and fs.lstatSync(path.resolve(filepath)).isDirectory()
      return

    ext = path.extname filepath

    if target is 'client'
      if ext is '.coffee'
        task = 'angular-coffee'
      else if ext is '.html'
        task = 'angular-views'
    else if target is 'server'
      if ext is '.coffee'
        task = 'server-coffee'
      else
        task = 'server-views'
    else if target is 'assets'
      if ext is '.less'
        task = 'less'
      else
        task = 'assets'

    if action is 'deleted'
      if task is 'less'
        dest = 'public/' + buildpack.config.pkg.name + '/' +  path.relative('src/assets', filepath)
        dest = dest.replace('.less', '')
        buildpack.config.clean['file'] = ["#{dest}.{less,css.map,css}"]
        grunt.task.run ['clean:file', 'reload-assets']
      else if task is 'assets'
        dest = 'public/' + buildpack.config.pkg.name + '/' +  path.relative('src/assets', filepath)
        buildpack.config.clean['file'] = [dest]
        grunt.task.run ['clean:file', 'reload-assets']
      else if task is 'angular-coffee'
        dest = 'public/' + buildpack.config.pkg.name + '/js/' +  path.relative('src/client', filepath)
        dest = dest.replace('.coffee', '')
        buildpack.config.clean['file'] = ["#{dest}.{coffee,js.map,js}"]
        grunt.task.run ['clean:file', 'reload-assets']
      else if task is 'angular-views'
        dest = 'public/' + buildpack.config.pkg.name + '/js/' +  path.relative('src/client', filepath)
        buildpack.config.clean['file'] = [dest]
        grunt.task.run ['clean:file', 'reload-assets']
      else if task is 'server-views'
        dest = 'lib/server/' +  path.relative('src/server', filepath)
        buildpack.config.clean['file'] = [dest]
        grunt.task.run ['clean:file', 'restart-nodemon']
      else if task is 'server-coffee'
        dest = 'lib/server/' +  path.relative('src/server', filepath)
        dest = dest.replace('.coffee', '.js')
        buildpack.config.clean['file'] = [dest]
        grunt.task.run ['clean:file', 'restart-nodemon']
      else
        grunt.task.run ['reload-assets']
      return


    if task is 'server-coffee'
      buildpack.config.coffeelint.server = filepath
      buildpack.config.coffee['server'].src = path.relative \
        buildpack.config.coffee['server'].cwd, filepath

    else if task is 'server-views'
      buildpack.config.copy['server-views'].files[0].src = path.relative \
        buildpack.config.copy['server-views'].files[0].cwd, filepath

    else if task is 'angular-coffee'
      buildpack.config.coffeelint.angular = filepath
      buildpack.config.coffee['angular'].src = path.relative \
        buildpack.config.coffee['angular'].cwd, filepath
      buildpack.config.copy['angular-coffee'].files[0].src = path.relative \
        buildpack.config.copy['angular-coffee'].files[0].cwd, filepath
      mapfilepath = path.join 'public/js/',
        path.relative('src/client/', filepath).replace('.coffee', '.js.map')
      buildpack.config.replace['sourcemaps'].src = mapfilepath

    else if task is 'angular-views'
      buildpack.config.copy['angular-views'].files[0].src = path.relative \
        buildpack.config.copy['angular-views'].files[0].cwd, filepath

    else if task is 'less'
      buildpack.config.copy['assets'].files[0].src = path.relative \
      buildpack.config.copy['assets'].files[0].cwd, filepath
      src = 'public/' + buildpack.config.pkg.name + '/' +  path.relative('src/assets', filepath)
      dest = src.replace('.less', '.css')
      changed = [dest]

      if not buildpack.config.less['recompile']?
        buildpack.config.less = {}
        buildpack.config.less['recompile'] = {}
        buildpack.config.less['recompile'].options = {}
        buildpack.config.less['recompile'].options.sourceMap = true
        buildpack.config.less['recompile'].options.ieCompat = true
        buildpack.config.less['recompile'].options.sourceMapBasepath = ''
        buildpack.config.less['recompile'].options.sourceMapRootpath = '/'

      buildpack.config.less['recompile'].files = {}
      buildpack.config.less['recompile'].files[dest] = src
      buildpack.config.less['recompile'].options.sourceMapFilename = dest + '.map'

    else if task is 'assets'
      buildpack.config.copy['assets'].files[0].src = path.relative \
        buildpack.config.copy['assets'].files[0].cwd, filepath

    # Run tasks
    tasks = []
    if task is 'angular-coffee'
      tasks = [
        'coffeelint:angular',
        'coffee:angular',
        'copy:angular-coffee',
        'replace:sourcemaps',
        'reload-browser',
        'livereload'
      ]
    else if task is 'angular-views'
      tasks = [
        'copy:angular-views',
        'reload-browser',
        'livereload'
      ]
    else if task is 'server-coffee'
      tasks = [
        'coffeelint:server',
        'coffee:server',
        'restart-nodemon'
      ]
    else if task is 'server-views'
      tasks = [
        'copy:server-views',
        'reload-browser',
        'livereload'
      ]
    else if task is 'less'
      tasks = [
        'copy:assets',
        'less',
        'reload-browser',
        'livereload'
      ]
    else if task is 'assets'
      tasks = [
        'copy:assets',
        'reload-browser',
        'livereload'
      ]

    if action is 'added'
      if target is 'assets' or target is 'client'
        tasks.splice tasks.length - 1, 1, 'reload-assets'

    grunt.task.run tasks

  return buildpack
