gulp   = require 'gulp'
coffee = require 'gulp-coffee'
qunit  = require 'gulp-qunit'
concat = require 'gulp-concat'

gulp.task 'default', ->
  console.log('default task called')

gulp.task 'scripts', ->
  gulp.src 'src/*.coffee'
    .pipe concat 'localforage_adapter.coffee'
    .pipe gulp.dest 'build' # Save the intermediate concatenated file
    .pipe coffee bare: true, sourceMap: true
    .pipe gulp.dest 'build'

gulp.task 'test', ->
  gulp.src './test/index.html'
    .pipe qunit()

gulp.task 'watch', ->
  gulp.watch 'src/*.coffee', ['scripts']
