const gulp = require('gulp')
const lcov = require('gulp-lcov-to-html')

gulp.task('generate-coverage-report', function () {

    return gulp
        .src("test/**/coverage.info") // grab the lcov files
        .pipe(lcov({
            name : "My WebApp"
        })) 
        .pipe(gulp.dest(".coverage")) // output to .coverage folder

});
