path = require 'path'
fs = require 'fs'
minimatch = require 'minimatch'

module.exports = (projectDir, grunt, master) ->
  reldir = path.relative(__dirname, projectDir)

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

  buildpack = {}

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
    'grunt-vhosted',
    'grunt-supervisor'
  ]

  buildpack.tasks = {}

  buildpack.tasks.default = ['install']

  buildpack.tasks.init = ['clean:init']

  buildpack.tasks.develop = [
    'clean:build',
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
    'ngtemplates',
    'easyassets:version-js',
    'uglify:production',
    'easyassets:version-other',
    'copy:easyassets-other',
    'easyassets:replace'
  ]

  # Build
  buildpack.build = (config, tasks) ->
    if not config?
      config = buildpack.config
    if not tasks?
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
      grunt.task.run tasks.develop
    grunt.registerTask 'debug', tasks.debug
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
      'server-coffee':
        files: ['src/server/**/*.coffee']
        tasks: ['coffeelint:server', 'coffee:server', 'restart-nodemon']
        options:
          spawn: false
          livereload: false
      'server-views':
        files: ['src/server/**/*.*', '!src/server/**/*.coffee']
        tasks: ['copy:server-views', 'reload-browser']
        options:
          spawn: false
          livereload: not slave
      'angular-coffee':
        files: ['src/client/**/*.coffee']
        tasks: [
          'coffeelint:angular',
          'coffee:angular',
          'copy:angular-coffee',
          'replace:sourcemaps',
          'reload-browser'
        ]
        options:
          spawn: false
          livereload: not slave
      'angular-views':
        files: ['src/client/**/*.html']
        tasks: ['copy:angular-views', 'reload-browser']
        options:
          spawn: false
          livereload: not slave
      'less':
        files: ['src/assets/less/**/*.less']
        tasks: ['less', 'reload-browser']
        options:
          spawn: false
          livereload: not slave
      'assets':
        files: [
          'src/assets/**/*.*',
          '!src/assets/assets.json'
        ]
        tasks: ['copy:assets', 'reload-browser']
        options:
          spawn: false
          livereload: not slave
      'easyassets':
        files: ['src/assets/assets.json']
        tasks: [
          'read-assets',
          'easyassets:parse',
          'restart-nodemon'
        ]
        options:
          spawn: false
          livereload: false
      'nodemon':
        files: ['.tmp/reload']
        options:
          livereload: not slave
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
      'development':
        options:
          compress:
            drop_console: false
        files: '<%= assets.js %>'
    replace:
      'sourcemaps':
        src: ['public/<%= pkg.name %>/js/**/*.js.map']
        overwrite: true
        replacements: [
          from: /\s*.*?sourceRoot.*?\,/g
          to: ''
        ]
    less:
      'assets':
        options:
          paths: ['public/']
          sourceMap: true
          outputSourceFiles: true
          ieCompat: true
        expand: true
        cwd: 'src/assets/'
        src: '**/*.less'
        dest: 'public/<%= pkg.name %>/'
        ext: '.css'
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
    if target is 'server-coffee'
      if fs.lstatSync(filepath).isDirectory()
        buildpack.config.coffeelint.server = []
        buildpack.config.coffee.server = []
      else
        buildpack.config.coffeelint.server = filepath
        buildpack.config.coffee['server'].src = path.relative \
          buildpack.config.coffee['server'].cwd, filepath

    else if target is 'server-views'
      buildpack.config.copy['server-views'].files[0].src = path.relative \
        buildpack.config.copy['server-views'].files[0].cwd, filepath

    else if target is 'angular-coffee'
      buildpack.config.coffeelint.angular = filepath
      buildpack.config.coffee['angular'].src = path.relative \
        buildpack.config.coffee['angular'].cwd, filepath
      buildpack.config.copy['angular-coffee'].files[0].src = path.relative \
        buildpack.config.copy['angular-coffee'].files[0].cwd, filepath
      mapfilepath = path.join 'public/js/',
        path.relative('src/client/', filepath).replace('.coffee', '.js.map')
      buildpack.config.replace['sourcemaps'].src = mapfilepath

    else if target is 'angular-views'
      buildpack.config.copy['angular-views'].files[0].src = path.relative \
        buildpack.config.copy['angular-views'].files[0].cwd, filepath

    else if target is 'less'
      buildpack.config.less['assets'].src = path.relative \
        buildpack.config.less['assets'].cwd, filepath

    else if target is 'assets'
      buildpack.config.copy['assets'].files[0].src = path.relative \
        buildpack.config.copy['assets'].files[0].cwd, filepath

    if action is 'added' or action is 'deleted'
      fs.writeFileSync '.tmp/restart', 'restart'

  return buildpack
