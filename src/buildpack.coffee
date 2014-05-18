path = require 'path'
fs = require 'fs'

module.exports = (projectdir, grunt, meanstack, type) ->
  reldir = path.relative(__dirname, projectdir)

  # Create tmp dir
  if not fs.existsSync "#{projectdir}/.tmp"
    fs.mkdirSync "#{projectdir}/.tmp"

  mean = {}

  mean.tasks = {}

  mean.tasks.default = ['install']

  mean.tasks.init = ['clean:init']

  mean.tasks.develop = [
    'clean:build',
    'copy:assets',
    'copy:angular-views',
    'less',
    'easyassets:version-css',
    'coffeelint:server',
    'coffeelint:angular',
    'coffee:angular-development',
    'copy:angular-coffee',
    'replace',
    'easyassets:version-js',
    'easyassets:replace-development',
    'concurrent:development'
  ]

  mean.tasks.preview = [
    'clean:build',
    'coffee:other',
    'copy:assets',
    'copy:server-views',
    'htmlmin',
    'less',
    'easyassets:version-css',
    'cssmin',
    'coffeelint:server',
    'coffee:server',
    'coffeelint:angular',
    'coffee:angular-production',
    'ngtemplates',
    'easyassets:version-js',
    'uglify:production',
    'easyassets:version-other',
    'copy:easyassets-other',
    'easyassets:replace-production',
    'clean:release',
    'nodemon:production'
  ]

  mean.tasks.install = [
    'vhosted',
    'clean:build',
    'coffee:other',
    'copy:assets',
    'copy:server-views',
    'htmlmin',
    'less',
    'easyassets:version-css',
    'cssmin',
    'coffeelint:server',
    'coffee:server',
    'coffeelint:angular',
    'coffee:angular-production',
    'ngtemplates',
    'easyassets:version-js',
    'uglify:production',
    'easyassets:version-other',
    'copy:easyassets-other',
    'easyassets:replace-production',
    'clean:release'
  ]

  # Build
  mean.build = (config, tasks) ->
    if not config?
      config = mean.config
    if not tasks?
      tasks = mean.tasks
    grunt.initConfig mean.config

    # Load NPM tasks
    grunt.file.setBase path.resolve(__dirname, '../')
    for npmtask in mean.npmtasks
      grunt.loadNpmTasks npmtask
    grunt.file.setBase projectdir

    grunt.registerTask 'default', tasks.default
    grunt.registerTask 'init', tasks.init
    grunt.registerTask 'develop', tasks.develop
    grunt.registerTask 'preview', tasks.preview
    grunt.registerTask 'install', tasks.install
    grunt.event.on 'watch', (action, filepath, target) ->
      mean.watch grunt, mean, action, filepath, target


  # Config
  mean.config =
    pkg: grunt.file.readJSON 'package.json'
    assets: grunt.file.readJSON 'assets.json'
    concurrent:
      'development':
        tasks: ['nodemon:development', 'watch']
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
          watch: ['src/server/**/*', '.tmp/restart', 'vhosts.coffee']
          ignore: ['src/server/views/**/*']
          ext: 'coffee,html,json'
          nodeArgs: ['--nodejs', '--debug'],
          delay: 1
          cwd: projectdir
          env:
            NODE_ENV: 'development'
            PORT: '3000'
          callback: (nodemon) ->
            nodemon.on 'log', (event) ->
              console.log event.colour
            nodemon.on 'restart', ->
              setTimeout ->
                fs.writeFileSync '.tmp/reload', 'reload'
              , 1000
      'production':
        script: 'server.js'
        options:
          watch: ['!']
          delay: 0
          cwd: projectdir
          env:
            NODE_ENV: 'production'
            PORT: '3000'
    watch:
      'server-coffee':
        files: ['src/server/**/*.coffee']
        tasks: ['coffeelint:server']
        options:
          spawn: false
          livereload: false
      'server-views':
        files: ['src/server/views/**/*.*']
        tasks: []
        options:
          spawn: false
          livereload: true
      'angular-coffee':
        files: ['src/client/**/*.coffee']
        tasks: [
          'coffeelint:angular',
          'coffee:angular-development',
          'copy:angular-coffee',
          'replace:sourcemaps'
        ]
        options:
          spawn: false
          livereload: true
      'angular-views':
        files: ['src/client/**/*.html']
        tasks: ['copy:angular-views']
        options:
          spawn: false
          livereload: true
      'less':
        files: ['src/assets/less/**/*.less']
        tasks: ['less', 'easyassets:replace-development']
        options:
          spawn: false
          livereload: true
      'assets':
        files: [
          'src/assets/**/*.*'
        ]
        tasks: ['copy:assets']
        options:
          spawn: false
          livereload: true
      'easyassets':
        files: ['assets.json']
        tasks: [
          'easyassets:version-js',
          'easyassets:version-css',
          'easyassets:version-other',
          'easyassets:replace-development'
        ]
        options:
          spawn: false
          livereload: false
      'nodemon':
        files: [
          '.tmp/reload',
          'public/**/*',
          '!public/css/**/*',
          '!public/js/**/*',
          '!public/vendor/**/*',
          '!public/plugins/**/*'
        ]
        options:
          livereload: true
    coffee:
      'server':
        options:
          bare: true
        expand: true
        cwd: 'src/server/'
        src: ['**/*.coffee']
        dest: 'lib/server/'
        ext: '.js'
      'angular-production':
        options:
          bare: false
        expand: true
        cwd: 'src/client/'
        src: ['**/*.coffee']
        dest: 'public/js/'
        ext: '.js'
      'angular-development':
        options:
          bare: false
          sourceMap: true
        expand: true
        cwd: 'src/client/'
        src: ['**/*.coffee']
        dest: 'public/js/'
        ext: '.js'
      'other':
        options:
          bare: true
        files:
          'app.js': 'app.coffee'
          'server.js': 'server.coffee'
          'vhosts.js': 'vhosts.coffee'
    coffeelint:
      'server': ['src/server/**/*.coffee']
      'angular': ['src/client/**/*.coffee']
    copy:
      'server-views':
        files: [
          expand: true
          cwd: 'src/server/views/'
          src: '**/*.*'
          dest: 'lib/server/views/'
        ]
      'angular-coffee':
        files: [
          expand: true
          cwd: 'src/client/'
          src: '**/*.coffee'
          dest: 'public/js/'
        ]
      'angular-views':
        files: [
          expand: true
          cwd: 'src/client/'
          src: '**/*.html'
          dest: 'public/js/'
        ]
      'assets':
        files: [
          expand: true
          cwd: 'src/assets/'
          src: ['**/*.*']
          dest: 'public/'
        ]
      'easyassets-other':
        files: '<%= assets.other %>'
    clean:
      options:
        force: true
      'init': [
        'app.js',
        'server.js',
        'vhosts.js',
        '.assets',
        'lib/',
        'public/',
        '.tmp/'
      ]
      'build': [
        'app.js',
        'server.js',
        'vhosts.js',
        '.assets',
        'lib/',
        'public/**/*',
        '!public/vendor/**',
        '!public/plugins/**',
        '!public/other/**'
      ]
      'release': [
        'public/**/*',
        '!public/*.*',
        '!public/release/**',
        '!public/vendor/**',
        '!public/plugins/**',
        '!public/other/**'
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
        src: ['public/js/**/*.js.map']
        overwrite: true
        replacements: [
          from: /\s*.*?sourceRoot.*?\,/g
          to: ''
        ]
    less:
      'assets':
        options:
          paths: ['src/assets/less/', 'public/vendor/', 'public/plugins/']
          sourceMap: true
          outputSourceFiles: true
          ieCompat: true
        expand: true
        cwd: 'src/assets/less/'
        src: '**/*.less'
        dest: 'public/css/'
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
          dest: 'public/js/'
        ]
    easyassets:
      options:
        dumpvar: 'assets'
        prefix: 'public/'
      'version-js':
        assets: '<%= assets %>'
        options:
          version: 'js'
          hashlength: 10
      'version-css':
        assets: '<%= assets %>'
        options:
          version: 'css'
          hashlength: 10
      'version-other':
        assets: '<%= assets %>'
        options:
          version: 'other'
          hashlength: 10
      'replace-production':
        assets: '<%= assets %>'
        options:
          debug: false
          dumpfile: '.assets'
          ignore: []
          webroot: 'public/'
          replace: [
            ignore: ['public/vendor/**/*', 'public/plugins/**/*']
            src: 'other'
            dest: ['css']
          ]
      'replace-development':
        assets: '<%= assets %>'
        options:
          debug: true
          dumpfile: '.assets'
          ignore: []
          webroot: 'public/'
          replace: [
            ignore: ['public/vendor/**/*', 'public/plugins/**/*']
            src: 'other'
            dest: ['css']
          ]
    vhosted:
      vhosts: () ->
        meanstack.project(projectdir, projectdir + '/src/server',
          '.coffee', null, false).resolve require("#{reldir}/vhosts.coffee")

  name = mean.config.pkg.name.replace '-', '.'
  mean.config.ngtemplates = {}
  mean.config.ngtemplates[name] = {}
  mean.config.ngtemplates[name] =
    options:
      prefix: 'public/js/'
    cwd: 'public/js/'
    src: '**/*.html'
    dest: 'public/js/partials.js'

  if type is 'project'
    mean = require('./project')(projectdir, grunt, mean)
  else if type is 'plugin'
    mean = require('./plugin')(projectdir, grunt, mean)

  return mean
