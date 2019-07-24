function HTMLClassRemove (e, cls)
{
  e.className = e.className.replace (cls, '');
}

function HTMLClassAdd (e, cls)
{
  if (e.className.indexOf (cls) == -1)
    e.className += ' '+cls;
}

function HTMLClassReplace (e, cls1, cls2)
{
  HTMLClassRemove (e, cls1);
  HTMLClassAdd (e, cls2);
}

function updateActionsChecked (form, target, name)
{
  for (var i = 0, len = form.elements.length; i < len; i++)
  {
    var e = form.elements[i];

    if (e.type == 'checkbox' && e.checked && e.name.indexOf(name) != -1)
      return HTMLClassRemove (target, 'disabled');
  }

  HTMLClassAdd (target, 'disabled');
}

function checkUncheckAll (e, name, checkedText, uncheckedText)
{
  var r = document.querySelectorAll ('input[name^="'+name+'"]');
  var v = e.getAttribute ('data-checked');

  for (var i = 0, len = r.length; i < len; i++)
    r[i].checked = (v == 0);

  if (v == 1)
  {
    e.setAttribute ('data-checked', 0);
    HTMLClassReplace (e.querySelector('i'), 'fa-square-o', 'fa-check-square-o');
    e.querySelector('span').innerText = checkedText;
  }
  else
  {
    e.setAttribute ('data-checked', 1);
    HTMLClassReplace (e.querySelector('i'), 'fa-check-square-o', 'fa-square-o');
    e.querySelector('span').innerText = uncheckedText;
  }
}

function displayMsg (msg, type, title)
{
  var e = document.getElementById ('clamav-msg');

  e.innerHTML =
    "<button class='close' onclick='document.getElementById(\"clamav-msg\").style.display=\"none\"'>&times;</button>"+((title)?"<strong>"+title+"</strong>":'')+"<p>"+msg+"</p>";

  e.className = 'alert alert-'+((type)?type:'info');
  e.style.display = 'block';
}

