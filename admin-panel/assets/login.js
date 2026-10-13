(function () {
  'use strict';

  const steps = document.querySelectorAll('.step');
  const otpInputs = [...document.querySelectorAll('#otp input')];
  let challenge = '';
  async function request(path, body) {
    const response = await fetch(path, {method:'POST', credentials:'same-origin',
      headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)});
    const result = await response.json().catch(() => ({error:'Сервер недоступен'}));
    if (!response.ok) throw new Error(result.error || 'Не удалось войти');
    return result;
  }

  function showStep(n) {
    steps.forEach((s) => s.classList.toggle('is-active', s.dataset.step === String(n)));
    if (n === 1) document.getElementById('password').focus();
    if (n === 2) { otpInputs.forEach((i) => { i.value = ''; }); otpInputs[0].focus(); }
  }

  const fail = (id, text) => { const box = document.getElementById(id); box.textContent = text; box.classList.add('is-visible'); };
  const clearErr = (id) => document.getElementById(id).classList.remove('is-visible');

  async function withLoading(form, fn) {
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    try { await fn(); } finally { btn.disabled = false; }
  }

  const eye = document.getElementById('eye');
  eye.addEventListener('click', () => {
    const pw = document.getElementById('password');
    const show = pw.type === 'password';
    pw.type = show ? 'text' : 'password';
    eye.querySelector('use').setAttribute('href', show ? '#i-eye-off' : '#i-eye');
    eye.setAttribute('aria-label', show ? 'Скрыть пароль' : 'Показать пароль');
  });

  document.getElementById('loginForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    const username = form.username.value.trim();
    const password = form.password.value;
    clearErr('err1');
    if (!username || !password) return fail('err1', 'Введите логин и пароль');
    withLoading(form, async () => {
      try {
        challenge = (await request('/api/auth/login', {username, password})).challenge;
        form.password.value = '';
      } catch (error) { return fail('err1', error.message); }
      showStep(2);
    });
  });

  document.getElementById('back').addEventListener('click', () => { clearErr('err2'); showStep(1); });

  // OTP: автопереход, Backspace назад, вставка целого кода
  otpInputs.forEach((input, idx) => {
    input.addEventListener('input', () => {
      input.value = input.value.replace(/\D/g, '').slice(-1);
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
      otpInputs.forEach((i, k) => { i.value = digits[k] || ''; });
      otpInputs[Math.min(digits.length, 5)].focus();
      if (digits.length === 6) document.getElementById('mfaForm').requestSubmit();
    });
  });

  document.getElementById('mfaForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    if (form.querySelector('button[type=submit]').disabled) return;
    const code = otpInputs.map((i) => i.value).join('');
    clearErr('err2');
    if (code.length !== 6) return fail('err2', 'Введите все 6 цифр');
    withLoading(form, async () => {
      try { await request('/api/auth/mfa', {challenge, code}); }
      catch (error) { showStep(2); return fail('err2', error.message); }
      location.href = 'dashboard.html';
    });
  });
})();
