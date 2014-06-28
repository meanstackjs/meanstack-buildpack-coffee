path = require 'path'
fs = require 'fs'
request = require 'request'
_ = require('lodash')

module.exports = (projectDir, grunt) ->
  reldir = path.relative(__dirname, projectDir)

  # Create tmp dir
  if not fs.existsSync "#{projectDir}/.tmp"
    fs.mkdirSync "#{projectDir}/.tmp"
  fs.writeFileSync '.tmp/reload', 'reload'
  fs.writeFileSync '.tmp/restart', 'restart'

  grunt.task.registerTask 'restart-nodemon', 'Restarts nodemon.', ->
    fs.writeFileSync '.tmp/restart', 'restart'

  grunt.task.registerTask 'reload-assets', 'Reloads assets.', ->
    grunt.task.run ['read-assets', 'easyassets:parse', 'restart-nodemon']

  grunt.task.registerTask 'less-config', 'Configures less task.', ->
    files = grunt.file.expand 'src/*/assets/**/*.less'
    for file in files
        cfg = {}
        cfg.files = {}
        chunks = file.split(path.sep)
        src = 'public/' + chunks[1] + '/' +  path.relative("src/#{chunks[1]}", file)
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

  buildpack.npmtasks = [
    'grunt-contrib-copy',
    'grunt-contrib-coffee',
    'grunt-contrib-uglify',
    'grunt-contrib-clean',
    'grunt-contrib-less',
    'grunt-contrib-cssmin',
    'grunt-contrib-htmlmin',
    'grunt-coffeelint',
    'grunt-text-replace',
    'grunt-easyassets',
    'grunt-chokiwatch',
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

    # Read and merge assets
    grunt.registerTask 'read-assets', 'Loads asset config.', ->
      assetPaths = grunt.file.expand 'src/*/assets/assets.json'
      assetObject =
        js: {}
        css: {}
        other: {}
      for assetFile in assetPaths
        data = grunt.file.readJSON(assetFile)
        if data.js?
          assetObject.js = _.assign assetObject.js, data.js
        if data.css?
          assetObject.css = _.assign assetObject.css, data.css
        if data.other?
          assetObject.other = _.assign assetObject.other, data.other
      buildpack.config.assets = assetObject

    # Register tasks
    grunt.registerTask 'default', tasks.default
    grunt.registerTask 'init', tasks.init
    grunt.registerTask 'develop', tasks.develop
    grunt.registerTask 'debug', tasks.debug
    grunt.registerTask 'preview', tasks.preview
    grunt.registerTask 'install', tasks.install

  # Configuration
  buildpack.config =
    pkg: grunt.file.readJSON 'package.json'
    concurrent:
      'development':
        tasks: ['nodemon:development', 'chokiwatch']
        options:
          logConcurrentOutput: true
      'debug':
        tasks: ['nodemon:debug', 'chokiwatch']
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
    chokiwatch:
      options:
        livereload:
          enabled: true
      'server':
        paths: ['src/*/server', 'src/*.coffee']
        callback: (config, event, filepath) ->
          ext = path.extname filepath
          if ext is '.coffee'
            task = 'server-coffee'
          else
            task = 'server-views'
          if event is 'unlinkDir'
            dest = 'lib/' +  path.relative('src', filepath)
            config.clean['file'] = [dest]
            return ['clean:file', 'restart-nodemon']
          else if event is 'unlink'
            dest = 'lib/' +  path.relative('src', filepath)
            if task is 'server-coffee'
              dest = dest.replace('.coffee', '.js')
            config.clean['file'] = [dest]
            return ['clean:file', 'restart-nodemon']
          else if event in ['add', 'change']
            if task is 'server-coffee'
              config.coffeelint.server = filepath
              config.coffee['server'].src = path.relative \
                config.coffee['server'].cwd, filepath
              return ['coffeelint:server', 'coffee:server', 'restart-nodemon']
            else if task is 'server-views'
              config.copy['server-views'].files[0].src = path.relative \
                config.copy['server-views'].files[0].cwd, filepath
              return ['copy:server-views', 'chokiwatch:livereload']
      'client':
        paths: ['src/*/client']
        callback: (config, event, filepath) ->
          ext = path.extname filepath
          if ext is '.coffee'
            task = 'angular-coffee'
          else
            task = 'angular-views'
          if event is 'unlinkDir'
            dest = 'public/' +  path.relative('src', filepath)
            config.clean['file'] = [dest]
            return ['clean:file', 'reload-assets']
          else if event is 'unlink'
            dest = 'public/' +  path.relative('src', filepath)
            if task is 'angular-coffee'
              dest = dest.replace('.coffee', '')
              config.clean['file'] = ["#{dest}.{coffee,js.map,js}"]
            else if task is 'angular-views'
              config.clean['file'] = [dest]
            return ['clean:file', 'reload-assets']
          else if event in ['add', 'change']
            if task is 'angular-coffee'
              config.coffeelint.angular = filepath
              config.coffee['angular'].src = path.relative \
                config.coffee['angular'].cwd, filepath
              config.copy['angular-coffee'].files[0].src = path.relative \
                config.copy['angular-coffee'].files[0].cwd, filepath
              mapfilepath = path.join 'public/',
                path.relative('src', filepath).replace('.coffee', '.js.map')
              config.replace['sourcemaps'].src = mapfilepath
              tasks = [
                'coffeelint:angular',
                'coffee:angular',
                'copy:angular-coffee',
                'replace:sourcemaps',
                'chokiwatch:livereload'
              ]
            else if task is 'angular-views'
              config.copy['angular-views'].files[0].src = path.relative \
                config.copy['angular-views'].files[0].cwd, filepath
              tasks = [
                'copy:angular-views',
                'chokiwatch:livereload'
              ]
            if event is 'add'
              tasks.splice tasks.length - 1, 1, 'reload-assets'
            return tasks
      'assets':
        paths: ['src/*/assets']
        ignore: ['src/*/assets/assets.json']
        callback: (config, event, filepath, stat, reload) ->
          ext = path.extname filepath
          if ext is '.less'
            task = 'less'
          else
            task = 'assets'
          if event is 'unlinkDir'
            dest = 'public/' +  path.relative('src', filepath)
            config.clean['file'] = [dest]
            return ['clean:file', 'reload-assets']
          else if event is 'unlink'
            dest = 'public/' +  path.relative('src', filepath)
            if task is 'less'
              dest = dest.replace('.less', '')
              config.clean['file'] = ["#{dest}.{less,css.map,css}"]
            else if task is 'assets'
              config.clean['file'] = [dest]
            return ['clean:file', 'reload-assets']
          else if event in ['add', 'change']
            if task is 'less'
              config.copy['assets'].files[0].src = path.relative \
              config.copy['assets'].files[0].cwd, filepath
              src = 'public/' +  path.relative('src', filepath)
              dest = src.replace('.less', '.css')
              reload.splice(0, reload.length, dest)

              if not config.less['recompile']?
                config.less = {}
                config.less['recompile'] = {}
                config.less['recompile'].options = {}
                config.less['recompile'].options.sourceMap = true
                config.less['recompile'].options.ieCompat = true
                config.less['recompile'].options.sourceMapBasepath = ''
                config.less['recompile'].options.sourceMapRootpath = '/'

              config.less['recompile'].files = {}
              config.less['recompile'].files[dest] = src
              config.less['recompile'].options.sourceMapFilename = dest + '.map'
              tasks = ['copy:assets', 'less', 'chokiwatch:livereload']
            else if task is 'assets'
              config.copy['assets'].files[0].src = path.relative \
                config.copy['assets'].files[0].cwd, filepath
              tasks = ['copy:assets', 'chokiwatch:livereload']

            if event is 'add'
              tasks.splice tasks.length - 1, 1, 'reload-assets'
            return tasks
      'easyassets':
        paths: ['src/*/assets/assets.json']
        tasks: ['reload-assets']
      'reload':
        livereload: true
        paths: ['.tmp/reload']
    coffee:
      'server':
        options:
          bare: true
        expand: true
        cwd: 'src/'
        src: ['*/server/**/*.coffee', '*.coffee']
        dest: 'lib/'
        ext: '.js'
      'angular':
        options:
          bare: false
          sourceMap: true
        expand: true
        cwd: 'src/'
        src: ['*/client/**/*.coffee']
        dest: 'public/'
        ext: '.js'
    coffeelint:
      options:
        'max_line_length':
          level: 'ignore'
      'server': ['src/*/server/**/*.coffee']
      'angular': ['src/*/client/**/*.coffee']
    copy:
      'server-views':
        files: [
          expand: true
          cwd: 'src/'
          src: ['*/server/**/*.*', '!*/server/**/*.coffee']
          dest: 'lib/'
        ]
      'angular-coffee':
        files: [
          expand: true
          cwd: 'src/'
          src: '*/client/**/*.coffee'
          dest: 'public/'
        ]
      'angular-views':
        files: [
          expand: true
          cwd: 'src/'
          src: '*/client/**/*.html'
          dest: 'public/'
        ]
      'assets':
        files: [
          expand: true
          cwd: 'src/'
          src: ['*/assets/**/*.*', '!*/assets/assets.json']
          dest: 'public/'
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
        'public/*/**/*',
        '!public/*/vendor/**',
        '!public/*/other/**',
        '!public/*.*'
      ]
      'release': [
        'public/*/**/*',
        '!public/*/*.*',
        '!public/*/release/**',
        '!public/*/vendor/**',
        '!public/*/other/**',
        '!public/*.*'
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
        src: ['public/*/client/**/*.js.map']
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
          cwd: 'src/'
          src: '*/client/**/*.html'
          dest: 'public/'
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
          value:
            prefix: '/'
          dumpfile: 'public/assets.json'
          ignore: []
          replace: [
            ignore: ['public/vendor/**/*']
            src: 'other'
            dest: ['css']
          ]
      'parse':
        assets: '<%= assets %>'
        parse: true
        options:
          debug: true
          value:
            prefix: '/'
          dumpfile: 'public/assets.json'
    vhosted:
      vhosts:
        src: [
          'src/*/package.json'
        ]

  buildpack.config.ngtemplates = {}
  packets = grunt.file.expand ['src/*/']
  for packet in packets
    packet = path.basename(packet)
    name = packet.replace('-', '.')
    buildpack.config.ngtemplates[name] = {}
    buildpack.config.ngtemplates[name] =
      options:
        prefix: "/public/#{packet}/client/"
      cwd: "public/#{packet}/client/"
      src: '**/*.html'
      dest: "public/#{packet}/client/partials.js"

  return buildpack
