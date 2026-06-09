/* Vinnie's Oil Australia — shared.js */

/* ─── NAV ACTIVE LINK ─── */
(function() {
  const page = location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('#navbar a[data-page]').forEach(a => {
    if (a.dataset.page === page) a.classList.add('active');
  });
})();

/* ─── MOBILE MENU ─── */
const hamburger = document.getElementById('nav-hamburger');
const mobileNav = document.getElementById('mobile-nav');
if (hamburger && mobileNav) {
  hamburger.addEventListener('click', () => {
    mobileNav.classList.toggle('open');
    hamburger.setAttribute('aria-expanded', mobileNav.classList.contains('open'));
  });
  document.addEventListener('click', e => {
    if (!hamburger.contains(e.target) && !mobileNav.contains(e.target)) {
      mobileNav.classList.remove('open');
    }
  });
}

/* ─── ACCORDION ─── */
document.querySelectorAll('.accordion-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const body = btn.nextElementSibling;
    const isOpen = btn.classList.contains('open');
    btn.classList.toggle('open', !isOpen);
    body.classList.toggle('open', !isOpen);
  });
});

/* ─── TABS ─── */
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const group = btn.closest('[data-tabs]');
    if (!group) return;
    group.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    group.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
    btn.classList.add('active');
    group.querySelector('[data-panel="' + btn.dataset.tab + '"]').classList.add('active');
  });
});

/* ─── BACK TO TOP ─── */
const btt = document.getElementById('back-top');
if (btt) {
  window.addEventListener('scroll', () => {
    btt.classList.toggle('visible', window.scrollY > 400);
  });
  btt.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));
}

/* ─── SCROLL ANIMATIONS (simple IntersectionObserver) ─── */
const revealEls = document.querySelectorAll('.reveal');
if (revealEls.length) {
  const io = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('revealed'); io.unobserve(e.target); }
    });
  }, { threshold: 0.12 });
  revealEls.forEach(el => io.observe(el));
}

/* ─── FORM SUBMIT (Formspree) ─── */
const contactForm = document.getElementById('contact-form');

if (contactForm) {
  contactForm.addEventListener('submit', async function (e) {
    e.preventDefault();

    const formData = new FormData(contactForm);

    const res = await fetch(contactForm.action, {
      method: 'POST',
      body: formData,
      headers: { 'Accept': 'application/json' }
    });

    if (res.ok) {
      const success = document.getElementById('form-success');
      if (success) success.style.display = 'flex';

      contactForm.reset();
    } else {
      alert('Something went wrong. Please try again.');
    }
  });
}
