// an example to create a new mapping `ctrl-y`
settings.blacklistPattern = /(^|\/\/)(docs)\.google\.com\//i;

api.mapkey('<ctrl-y>', 'Show me the money', function() {
    api.Front.showPopup('a well-known phrase uttered by characters in the 1996 film Jerry Maguire (Escape to close).');
});

api.map('>_f', 'f');   // 备份原 f
api.map('>_s', 's');   // 备份原 s

api.map('s', '>_f');   // s 变成原 f
api.map('f', '>_s');   // f 变成原 s

api.unmap('>_f');      // 可选：清理临时键
api.unmap('>_s');

// an example to replace `T` with `gt`, click `Default mappings` to see how `T` works.
api.map('gt', 'T');

api.map('J', 'd');
api.map('K', 'u');

// an example to remove mapkey `Ctrl-i`
api.imap('<ctrl-q>', '<ctrl-a>')
api.map('gs', ';fs');

api.iunmap('<ctrl-a>')
api.imapkey('<Ctrl-a>', 'Select all in focused input', function() {
  const el = document.activeElement;
  if (!el) return;

  if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
    el.select();
    return;
  }

  if (el.isContentEditable) {
    const r = document.createRange();
    r.selectNodeContents(el);
    const s = window.getSelection();
    s.removeAllRanges();
    s.addRange(r);
  }
});

api.mapkey('gh', 'Hover element (no click)', () => {
  api.Hints.create(
    'a, button, [role="button"], [onclick], input, textarea, select',
    (el) => {
      const r = el.getBoundingClientRect();
      const x = Math.round(r.left + r.width / 2);
      const y = Math.round(r.top + r.height / 2);

      const fire = (type) => {
        el.dispatchEvent(
          new MouseEvent(type, {
            bubbles: true,
            cancelable: true,
            view: window,
            clientX: x,
            clientY: y,
          })
        );
      };

      fire('mousemove');
      fire('mouseover');
      fire('mouseenter');
    }
  );
});

api.mapkey('gH', 'Unhover element (no click)', () => {
  api.Hints.create(
    'a, button, [role="button"], [onclick], input, textarea, select',
    (el) => {
      const r = el.getBoundingClientRect();
      const x = Math.round(r.left + r.width / 2);
      const y = Math.round(r.top + r.height / 2);

      const fire = (type) => {
        el.dispatchEvent(
          new MouseEvent(type, {
            bubbles: true,
            cancelable: true,
            view: window,
            clientX: x,
            clientY: y,
          })
        );
      };

      fire('mouseout');
      fire('mouseleave');
    }
  );
});


api.imapkey('<Ctrl-l>', 'Unfocus active input', () => {
  const el = document.activeElement;
  if (!el) return;

  const isEditable =
    el.tagName === 'INPUT' ||
    el.tagName === 'TEXTAREA' ||
    el.isContentEditable;

  if (isEditable && typeof el.blur === 'function') {
    el.blur();
  }

  let sink = document.getElementById('sk_focus_sink');
  if (!sink) {
    sink = document.createElement('div');
    sink.id = 'sk_focus_sink';
    sink.tabIndex = 0;
    sink.style.cssText = 'position:fixed;inset:0;width:1px;height:1px;opacity:0;pointer-events:none;';
    document.documentElement.appendChild(sink);
  }
  sink.focus();
});

// set theme
settings.theme = `
.sk_theme {
    font-family: Input Sans Condensed, Charcoal, sans-serif;
    font-size: 10pt;
    background: #24272e;
    color: #abb2bf;
}
.sk_theme tbody {
    color: #fff;
}
.sk_theme input {
    color: #d0d0d0;
}
.sk_theme .url {
    color: #61afef;
}
.sk_theme .annotation {
    color: #56b6c2;
}
.sk_theme .omnibar_highlight {
    color: #528bff;
}
.sk_theme .omnibar_timestamp {
    color: #e5c07b;
}
.sk_theme .omnibar_visitcount {
    color: #98c379;
}
.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
    background: #303030;
}
.sk_theme #sk_omnibarSearchResult ul li.focused {
    background: #3e4452;
}
#sk_status, #sk_find {
    font-size: 20pt;
}`;
// click `Save` button to make above settings to take effect.</ctrl-i></ctrl-y>
