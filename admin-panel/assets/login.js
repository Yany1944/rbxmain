// Макет входа: двухшаговая форма (пароль → TOTP). Сеть не трогает — всё имитация.
// Места для настоящих запросов помечены TODO(backend).
(function () {
  'use strict';

  const card = document.getElementById('card');
  const steps = document.querySelectorAll('.step');
  const otpInputs = [...document.querySelectorAll('#otp input')];
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));

  function showStep(n) {
    steps.forEach((s) => s.classList.toggle('is-active', s.dataset.step === String(n)));
    if (n === 1) document.getElementById('password').focus();
    if (n === 2) { otpInputs.forEach((i) => { i.value = ''; i.classList.remove('filled'); }); otpInputs[0].focus(); }
  }

  function fail(errId, text) {
    const box = document.getElementById(errId);
    box.querySelector('span').textContent = text;
    box.classList.remove('is-visible');
    void box.offsetWidth; // перезапуск анимации появления
    box.classList.add('is-visible');
    card.classList.remove('shake');
    void card.offsetWidth;
    card.classList.add('shake');
  }
  const clearErr = (id) => document.getElementById(id).classList.remove('is-visible');

  async function withLoading(form, fn) {
    const btn = form.querySelector('button[type=submit]');
    btn.classList.add('is-loading');
    btn.disabled = true;
    try { await fn(); } finally { btn.classList.remove('is-loading'); btn.disabled = false; }
  }

  // Показать/скрыть пароль
  const eye = document.getElementById('eye');
  eye.addEventListener('click', () => {
    const pw = document.getElementById('password');
    const show = pw.type === 'password';
    pw.type = show ? 'text' : 'password';
    eye.querySelector('use').setAttribute('href', show ? '#i-eye-off' : '#i-eye');
    eye.setAttribute('aria-label', show ? 'Скрыть пароль' : 'Показать пароль');
  });

  // Шаг 1
  document.getElementById('loginForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    const username = form.username.value.trim();
    const password = form.password.value;
    clearErr('err1');
    if (!username || !password) return fail('err1', 'Введите логин и пароль');

    withLoading(form, async () => {
      // TODO(backend): const r = await fetch('/api/auth/login', {method:'POST', credentials:'same-origin', headers:{'Content-Type':'application/json'}, body: JSON.stringify({username, password})});
      await wait(700);
      // Имитация: пароль короче 4 символов считаем неверным, чтобы было видно состояние ошибки
      if (password.length < 4) return fail('err1', 'Неверный логин или пароль');
      showStep(2);
    });
  });

  document.getElementById('back').addEventListener('click', () => { clearErr('err2'); showStep(1); });

  // OTP: автопереход, Backspace назад, вставка целого кода
  otpInputs.forEach((input, idx) => {
    input.addEventListener('input', () => {
      input.value = input.value.replace(/\D/g, '').slice(-1);
      input.classList.toggle('filled', !!input.value);
      if (input.value && idx < otpInputs.length - 1) otpInputs[idx + 1].focus();
      if (otpInputs.every((i) => i.value)) document.getElementById('mfaForm').requestSubmit();
    });
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Backspace' && !input.value && idx > 0) otpInputs[idx - 1].focus();
      if (e.key === 'ArrowLeft' && idx > 0) otpInputs[idx - 1].focus();
      if (e.key === 'ArrowRight' && idx < otpInputs.length - 1) otpInputs[idx + 1].focus();
    });
    input.addEventListener('paste', (e) => {
      const digits = (e.clipboardData.getData('text') || '').replace(/\D/g, '').slice(0, 6);
      if (!digits) return;
      e.preventDefault();
      otpInputs.forEach((i, k) => { i.value = digits[k] || ''; i.classList.toggle('filled', !!i.value); });
      otpInputs[Math.min(digits.length, 5)].focus();
      if (digits.length === 6) document.getElementById('mfaForm').requestSubmit();
    });
  });

  // Шаг 2
  document.getElementById('mfaForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    if (form.querySelector('button[type=submit]').disabled) return;
    const code = otpInputs.map((i) => i.value).join('');
    clearErr('err2');
    if (code.length !== 6) return fail('err2', 'Введите все 6 цифр');

    withLoading(form, async () => {
      // TODO(backend): await fetch('/api/auth/mfa', {method:'POST', credentials:'same-origin', ...})
      await wait(800);
      // Имитация: 000000 — неверный код
      if (code === '000000') { showStep(2); return fail('err2', 'Неверный код. Попробуйте ещё раз'); }
      card.style.transition = 'opacity .35s, transform .35s';
      card.style.opacity = '0';
      card.style.transform = 'translateY(-6px) scale(.99)';
      await wait(300);
      location.href = 'dashboard.html';
    });
  });

  // Таймер окна TOTP (30 секунд, как в Google Authenticator)
  const timer = document.getElementById('otpTimer');
  setInterval(() => {
    const left = 30 - (Math.floor(Date.now() / 1000) % 30);
    timer.textContent = `код обновится через ${left}с`;
  }, 1000);
})();
