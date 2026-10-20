(() => {
  const icon = document.getElementById('car-belt-item');
  if (!icon) return;

  let lastOn = null;

  // the green "buckled" confirmation fades out on its own, then the icon is gone
  icon.addEventListener('animationend', (event) => {
    if (event.animationName !== 'belt-confirm') return;
    icon.classList.remove('is-on');
    icon.style.display = 'none';
  });

  const setState = (state) => {
    icon.classList.toggle('is-off', state === 'off');
    icon.classList.toggle('is-on', state === 'on');
  };

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.type !== 'updateSeatbelt') return;

    const on = data.on === true;

    if (data.available === false) {
      setState(null);
      icon.style.display = 'none';
    } else if (!on) {
      // unbuckled: red icon fades in slowly, then blinks
      setState('off');
      icon.style.display = '';
    } else if (lastOn === false) {
      // just buckled: green icon fades in and out once
      setState('on');
      icon.style.display = '';
    } else if (!icon.classList.contains('is-on')) {
      setState(null);
      icon.style.display = 'none';
    }

    lastOn = on;
  });
})();
