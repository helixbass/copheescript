$(function(){
var closeMenus, compileSource, evalJS, hash, sourceFragment, src;

sourceFragment = "try:";

compileSource = function() {
  var el, location, message, results, source;
  source = $('#repl_source').val();
  results = $('#repl_results');
  window.compiledJS = '';
  try {
    window.compiledJS = CoffeeScript.compile(source, {
      bare: true
    });
    el = results[0];
    if (el.innerText) {
      el.innerText = window.compiledJS;
    } else {
      results.text(window.compiledJS);
    }
    results.removeClass('error');
    $('.minibutton.run').removeClass('error');
  } catch (_error) {
    location = _error.location, message = _error.message;
    if (location != null) {
      message = "Error on line " + (location.first_line + 1) + ": " + message;
    }
    results.text(message).addClass('error');
    $('.minibutton.run').addClass('error');
  }
  return $('#repl_permalink').attr('href', "#" + sourceFragment + (encodeURIComponent(source)));
};

$('#repl_source').keyup(function() {
  return compileSource();
});

evalJS = function() {
  var error;
  try {
    return eval(window.compiledJS);
  } catch (_error) {
    error = _error;
    return alert(error);
  }
};

window.loadConsole = function(coffee) {
  $('#repl_source').val(coffee);
  compileSource();
  $('.navigation.try').addClass('active');
  return false;
};

closeMenus = function() {
  return $('.navigation.active').removeClass('active');
};

$('.minibutton.run').click(function() {
  return evalJS();
});

$('.navigation').click(function(e) {
  if (e.target.tagName.toLowerCase() === 'a') {
    return;
  }
  if ($(e.target).closest('.repl_wrapper').length) {
    return false;
  }
  if ($(this).hasClass('active')) {
    closeMenus();
  } else {
    closeMenus();
    $(this).addClass('active');
  }
  return false;
});

$(document.body).keydown(function(e) {
  if (e.which === 27) {
    closeMenus();
  }
  if (e.which === 13 && (e.metaKey || e.ctrlKey) && $('.minibutton.run:visible').length) {
    return evalJS();
  }
}).click(function(e) {
  if ($(e.target).hasClass('minibutton')) {
    return false;
  }
  return closeMenus();
});

$('#open_webchat').click(function() {
  return $(this).replaceWith($('<iframe src="http://webchat.freenode.net/?channels=coffeescript" width="625" height="400"></iframe>'));
});

$("#repl_permalink").click(function(e) {
  window.location = $(this).attr("href");
  return false;
});

hash = decodeURIComponent(location.hash.replace(/^#/, ''));

if (hash.indexOf(sourceFragment) === 0) {
  src = hash.substr(sourceFragment.length);
  loadConsole(src);
}

compileSource();

});