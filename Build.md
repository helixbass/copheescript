To add to your existing repo:
``` shell
npm install helixbass/copheescript --save-dev
```

Config that we have to compile copheescript files
``` coffeescript
grunt.initConfig
    cophee:
      classes:
        files: [
          expand: yes
          cwd: '<%= paths.controller %>'
          src: [ '{,**/}*.php.cophee' ]
          dest: '<%= paths.controller %>'
          ext: '.php'
        ]
```
``` javascript
grunt.initConfig( {
    cophee: {
      classes: {
        files: [ {
          expand: true,
          cwd: '<%= paths.controller %>',
          src: [ '{,**/}*.php.cophee' ],
          dest: '<%= paths.controller %>',
          ext: '.php',
        }]
      }
    }
});
```

Path that cophee should look in to
``` coffeescript
grunt.initConfig
    paths:
      controller: 'application/classes/'
```
``` javascript
grunt.initConfig({
    paths: {
      controller: 'application/classes/'
    }
});
```


Compile all cophee script assets:
``` shell
grunt cophee
```

