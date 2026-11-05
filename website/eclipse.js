(() => {
  const button = document.querySelector('.effects-toggle');
  if (!button) return;
  let paused = matchMedia('(prefers-reduced-motion: reduce)').matches;
  try { paused = paused || localStorage.getItem('aternix-effects') === 'off'; } catch (_) {}
  function render() {
    document.body.classList.toggle('effects-paused', paused);
    button.setAttribute('aria-pressed', String(!paused));
    button.textContent = paused ? 'Efekty: vypnuto' : 'Efekty: zapnuto';
  }
  button.addEventListener('click', () => {
    paused = !paused;
    render();
    try { localStorage.setItem('aternix-effects', paused ? 'off' : 'on'); } catch (_) {}
  });
  document.addEventListener('visibilitychange', () => {
    document.body.classList.toggle('effects-hidden', document.hidden);
  });
  render();
})();
