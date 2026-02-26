const TRACKING_ENDPOINT = '/api/events';
const LEAD_ENDPOINT = '/api/leads';

function getSessionId() {
  const key = 'biotrack_lp_session_id';
  const existing = window.localStorage.getItem(key);
  if (existing) {
    return existing;
  }
  const created = (window.crypto && window.crypto.randomUUID)
    ? window.crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  window.localStorage.setItem(key, created);
  return created;
}

const sessionId = getSessionId();

function collectSource() {
  const params = new URLSearchParams(window.location.search);
  const utmSource = params.get('utm_source');
  const utmMedium = params.get('utm_medium');
  const utmCampaign = params.get('utm_campaign');

  if (utmSource || utmMedium || utmCampaign) {
    return ['utm', utmSource, utmMedium, utmCampaign].filter(Boolean).join(':').slice(0, 100);
  }

  return 'manual';
}

const sourceValue = collectSource();

function trackEvent(eventName, context = {}) {
  const payload = {
    event: eventName,
    path: window.location.pathname,
    referrer: document.referrer || '',
    session_id: sessionId,
    context
  };

  const body = JSON.stringify(payload);

  if (navigator.sendBeacon) {
    const blob = new Blob([body], { type: 'application/json; charset=utf-8' });
    navigator.sendBeacon(TRACKING_ENDPOINT, blob);
    return;
  }

  fetch(TRACKING_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body,
    keepalive: true
  }).catch(() => undefined);
}

function setFeedback(form, message, tone) {
  const feedback = form.querySelector('.form-feedback');
  if (!feedback) {
    return;
  }
  feedback.textContent = message;
  feedback.dataset.tone = tone;
}

function toPayload(formData) {
  return {
    first_name: String(formData.get('first_name') || '').trim(),
    last_name: String(formData.get('last_name') || '').trim(),
    email: String(formData.get('email') || '').trim(),
    primary_goal: String(formData.get('primary_goal') || '').trim(),
    consent_marketing: Boolean(formData.get('consent_marketing')),
    source: String(formData.get('source') || sourceValue),
    company: String(formData.get('company') || '').trim(),
    created_at: new Date().toISOString()
  };
}

function normalizeValidationError(fields = []) {
  if (fields.includes('consent_marketing')) {
    return 'Merci d\'accepter le consentement email pour rejoindre la waitlist.';
  }
  if (fields.includes('email')) {
    return 'Merci de saisir une adresse email valide.';
  }
  if (fields.includes('first_name') || fields.includes('last_name')) {
    return 'Merci de renseigner un prénom et un nom valides.';
  }
  if (fields.includes('primary_goal')) {
    return 'Merci de sélectionner un objectif principal.';
  }
  return 'Merci de vérifier les champs du formulaire.';
}

async function submitLeadForm(form, formLocation) {
  const formData = new FormData(form);
  const payload = toPayload(formData);

  const submitButton = form.querySelector('button[type="submit"]');
  if (submitButton) {
    submitButton.disabled = true;
    submitButton.textContent = 'Envoi en cours...';
  }

  setFeedback(form, '', '');

  try {
    const response = await fetch(LEAD_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload)
    });

    const json = await response.json().catch(() => ({}));

    if (response.status === 201 && json.success) {
      trackEvent('form_submit_success', { location: formLocation, goal: payload.primary_goal });
      setFeedback(form, 'Inscription reçue. Vérifie ton email pour confirmer.', 'success');

      const target = new URL('/merci.html', window.location.origin);
      target.searchParams.set('lead', json.lead_id || '');
      target.searchParams.set('email_status', 'pending_confirmation');
      if (json.debug_confirmation_url) {
        target.searchParams.set('debug_confirmation_url', json.debug_confirmation_url);
      }
      window.location.assign(target.toString());
      return;
    }

    if (response.status === 409) {
      setFeedback(form, 'Cette adresse est déjà inscrite à la waitlist.', 'error');
      trackEvent('form_submit_error', { location: formLocation, error: 'duplicate_email' });
      return;
    }

    if (response.status === 429) {
      setFeedback(form, 'Trop de tentatives. Merci de réessayer dans quelques minutes.', 'error');
      trackEvent('form_submit_error', { location: formLocation, error: 'rate_limit' });
      return;
    }

    if (response.status === 400) {
      setFeedback(form, normalizeValidationError(json.fields), 'error');
      trackEvent('form_submit_error', { location: formLocation, error: 'validation_error' });
      return;
    }

    setFeedback(form, 'Une erreur est survenue. Merci de réessayer.', 'error');
    trackEvent('form_submit_error', { location: formLocation, error: 'unexpected' });
  } catch {
    setFeedback(form, 'Impossible de contacter le serveur. Réessaye dans un instant.', 'error');
    trackEvent('form_submit_error', { location: formLocation, error: 'network' });
  } finally {
    if (submitButton) {
      submitButton.disabled = false;
      submitButton.textContent = formLocation === 'hero' ? 'Je réserve ma place' : 'Rejoindre maintenant';
    }
  }
}

function setupForms() {
  const forms = document.querySelectorAll('.lead-form');
  forms.forEach((form) => {
    const sourceField = form.querySelector('input[name="source"]');
    if (sourceField) {
      sourceField.value = sourceValue;
    }

    const location = form.dataset.formLocation || 'unknown';
    let hasStarted = false;

    const startHandler = () => {
      if (hasStarted) {
        return;
      }
      hasStarted = true;
      trackEvent('form_start', { location });
    };

    form.addEventListener('focusin', startHandler, { once: true });
    form.addEventListener('input', startHandler, { once: true });

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      submitLeadForm(form, location);
    });
  });
}

function setupRevealAnimations() {
  const items = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) {
    items.forEach((item) => item.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.18 }
  );

  items.forEach((item, index) => {
    item.style.transitionDelay = `${Math.min(index * 50, 240)}ms`;
    observer.observe(item);
  });
}

function setupCtaTracking() {
  document.querySelectorAll('.cta-button').forEach((button) => {
    button.addEventListener('click', () => {
      trackEvent('cta_click', { location: button.dataset.ctaLocation || 'unknown' });
    });
  });
}

function setupFaqTracking() {
  document.querySelectorAll('.faq-list details').forEach((detail) => {
    detail.addEventListener('toggle', () => {
      if (detail.open) {
        const summary = detail.querySelector('summary');
        trackEvent('faq_open', {
          question: summary ? summary.textContent.trim().slice(0, 100) : 'unknown'
        });
      }
    });
  });
}

window.addEventListener('DOMContentLoaded', () => {
  trackEvent('lp_view', {
    source: sourceValue,
    locale: document.documentElement.lang || 'fr'
  });

  setupForms();
  setupRevealAnimations();
  setupCtaTracking();
  setupFaqTracking();
});
