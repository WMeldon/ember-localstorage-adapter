gulp = require 'gulp'
coffee = require 'gulp-coffee'
qunit = require 'gulp-qunit'

gulp.task 'default', ->
  console.log('default task called')

gulp.task 'scripts', ->
  gulp.src 'src/*.coffee'
    .pipe gulp.dest 'build'
    .pipe coffee sourceMap: true
    # .pipe(uglify())
    # .pipe(concat('all.min.js'))
    .pipe gulp.dest 'build'


gulp.task 'test', ->
  gulp.src './test/index.html'
    .pipe qunit()

gulp.task 'watch', ->
  gulp.watch 'src/*.coffee', ['scripts']
