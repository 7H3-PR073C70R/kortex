/**
 * KORTEX SECURE INTERNAL STORAGE ENGINE
 * Enterprise Input Sanitization, CSV Formula Injection Mitigation (CWE-1236),
 * XSS Neutralization, and Secure Internal Lead Management.
 */

(function () {
  'use strict';

  const STORAGE_KEY_CONTACT = 'kortex_contact_submissions';
  const STORAGE_KEY_NEWSLETTER = 'kortex_newsletter_subscribers';
  const RATE_LIMIT_KEY = 'kortex_last_submission_ts';
  const RATE_LIMIT_COOLDOWN_MS = 10000; // 10 seconds cooldown between submissions

  // Whitelist of valid contact topics
  const ALLOWED_TOPICS = new Set([
    'early_access',
    'exam_past_questions',
    'feature_request',
    'campus_partnership',
    'bug_report',
    'other'
  ]);

  // --------------------------------------------------------------------------
  // 1. Bulletproof Sanitization & Security Filters
  // --------------------------------------------------------------------------

  /**
   * Strips all HTML/XML tags and neutralizes potential XSS vectors.
   */
  function stripHtml(input) {
    if (typeof input !== 'string') return '';
    return input
      .replace(/<[^>]*>/g, '') // Strip all HTML tags
      .replace(/javascript\s*:/gi, '') // Strip javascript: pseudo-protocols
      .replace(/data\s*:[^;]+;base64/gi, '') // Strip base64 data URIs
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, ''); // Strip control characters
  }

  /**
   * Mitigates CSV / Formula Injection (CWE-1236).
   * Prevents execution of spreadsheet formulas if cells start with =, +, -, @, \t, \r, %, or |.
   */
  function sanitizeForCSV(input) {
    const clean = stripHtml(input).trim();
    if (!clean) return '';
    // If field begins with dangerous formula characters, prefix with single quote to force text interpretation
    if (/^[=+\-@\t\r%|]/.test(clean)) {
      return "'" + clean;
    }
    return clean;
  }

  /**
   * RFC 5322-compliant email format check.
   */
  function isValidEmail(email) {
    if (typeof email !== 'string' || email.length > 254) return false;
    const emailRegex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;
    return emailRegex.test(email);
  }

  /**
   * Local storage safe retrieval.
   */
  function getStoredItems(key) {
    try {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : [];
    } catch (e) {
      return [];
    }
  }

  function setStoredItems(key, items) {
    try {
      localStorage.setItem(key, JSON.stringify(items));
    } catch (e) {
      console.warn('Local storage write blocked or quota exceeded.');
    }
  }

  // --------------------------------------------------------------------------
  // 2. Contact Message Submission Handler (Sanitized & Rate-Limited)
  // --------------------------------------------------------------------------
  function saveContactMessage({ name, email, topic, message, newsletterOptIn, honeypot }) {
    // 1. Honeypot check: If bot filled the hidden honeypot, silently reject
    if (honeypot && String(honeypot).trim().length > 0) {
      return { status: 'dropped', id: 'null' };
    }

    // 2. Client-side rate-limiting
    const now = Date.now();
    const lastSubmission = parseInt(localStorage.getItem(RATE_LIMIT_KEY) || '0', 10);
    if (now - lastSubmission < RATE_LIMIT_COOLDOWN_MS) {
      throw new Error('Please wait a few seconds before sending another message.');
    }

    // 3. Name sanitization and boundary check
    const cleanName = sanitizeForCSV(name);
    if (cleanName.length < 2 || cleanName.length > 100) {
      throw new Error('Please provide a valid name between 2 and 100 characters.');
    }

    // 4. Email sanitization and validation
    const cleanEmail = stripHtml(email).trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) {
      throw new Error('Please provide a valid student or personal email address.');
    }

    // 5. Topic whitelist check
    const cleanTopic = ALLOWED_TOPICS.has(topic) ? topic : 'other';

    // 6. Message sanitization and boundary check
    const cleanMessage = sanitizeForCSV(message);
    if (cleanMessage.length < 5 || cleanMessage.length > 3000) {
      throw new Error('Message must be between 5 and 3,000 characters.');
    }

    const submissions = getStoredItems(STORAGE_KEY_CONTACT);
    const newEntry = {
      id: 'msg_' + now + '_' + Math.random().toString(36).substring(2, 7),
      timestamp: new Date().toISOString(),
      name: cleanName,
      email: cleanEmail,
      topic: cleanTopic,
      message: cleanMessage,
      newsletterOptIn: Boolean(newsletterOptIn)
    };

    submissions.push(newEntry);
    setStoredItems(STORAGE_KEY_CONTACT, submissions);
    localStorage.setItem(RATE_LIMIT_KEY, String(now));

    // If opted into newsletter, automatically enroll safely
    if (newsletterOptIn) {
      saveNewsletterEmail(cleanEmail, 'contact_form_optin');
    }

    return { status: 'success', id: newEntry.id };
  }

  // --------------------------------------------------------------------------
  // 3. Newsletter Email Subscription Handler
  // --------------------------------------------------------------------------
  function saveNewsletterEmail(email, source = 'website') {
    const cleanEmail = stripHtml(email).trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) {
      throw new Error('Please enter a valid email address.');
    }

    const subscribers = getStoredItems(STORAGE_KEY_NEWSLETTER);
    const existing = subscribers.find((s) => s.email === cleanEmail);
    if (existing) {
      return { status: 'already_subscribed', email: cleanEmail };
    }

    const cleanSource = sanitizeForCSV(source).substring(0, 50) || 'website';
    const newSubscriber = {
      id: 'sub_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      timestamp: new Date().toISOString(),
      email: cleanEmail,
      source: cleanSource
    };

    subscribers.push(newSubscriber);
    setStoredItems(STORAGE_KEY_NEWSLETTER, subscribers);

    return { status: 'subscribed', email: cleanEmail };
  }

  function getStats() {
    const contacts = getStoredItems(STORAGE_KEY_CONTACT);
    const subscribers = getStoredItems(STORAGE_KEY_NEWSLETTER);
    return {
      contactCount: contacts.length,
      newsletterCount: subscribers.length,
      totalCount: contacts.length + subscribers.length
    };
  }

  // --------------------------------------------------------------------------
  // 4. RFC 4180 CSV Exporter (Internal Tooling)
  // --------------------------------------------------------------------------
  function escapeCSVCell(field) {
    if (field === null || field === undefined) return '""';
    const str = String(field);
    return '"' + str.replace(/"/g, '""') + '"';
  }

  function triggerDownload(csvString, filename) {
    const blob = new Blob(['\uFEFF' + csvString], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  function exportContactCSV() {
    const items = getStoredItems(STORAGE_KEY_CONTACT);
    if (items.length === 0) {
      alert('No contact submissions recorded.');
      return;
    }

    const headers = ['ID', 'Timestamp (ISO)', 'Name', 'Email', 'Topic', 'Message', 'Newsletter Opt-In'];
    const rows = items.map((i) => [
      escapeCSVCell(i.id),
      escapeCSVCell(i.timestamp),
      escapeCSVCell(i.name),
      escapeCSVCell(i.email),
      escapeCSVCell(i.topic),
      escapeCSVCell(i.message),
      escapeCSVCell(i.newsletterOptIn ? 'Yes' : 'No')
    ]);

    const csv = [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    triggerDownload(csv, `kortex_contacts_${new Date().toISOString().split('T')[0]}.csv`);
  }

  function exportNewsletterCSV() {
    const items = getStoredItems(STORAGE_KEY_NEWSLETTER);
    if (items.length === 0) {
      alert('No newsletter subscribers recorded.');
      return;
    }

    const headers = ['ID', 'Timestamp (ISO)', 'Email', 'Source'];
    const rows = items.map((i) => [
      escapeCSVCell(i.id),
      escapeCSVCell(i.timestamp),
      escapeCSVCell(i.email),
      escapeCSVCell(i.source)
    ]);

    const csv = [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    triggerDownload(csv, `kortex_subscribers_${new Date().toISOString().split('T')[0]}.csv`);
  }

  function exportAllCSV() {
    const contacts = getStoredItems(STORAGE_KEY_CONTACT);
    const subscribers = getStoredItems(STORAGE_KEY_NEWSLETTER);

    if (contacts.length === 0 && subscribers.length === 0) {
      alert('No records available for export.');
      return;
    }

    const headers = ['Type', 'ID', 'Timestamp (ISO)', 'Name', 'Email', 'Topic / Source', 'Message / Notes'];
    const rows = [];

    contacts.forEach((c) => {
      rows.push([
        escapeCSVCell('Contact Inquiry'),
        escapeCSVCell(c.id),
        escapeCSVCell(c.timestamp),
        escapeCSVCell(c.name),
        escapeCSVCell(c.email),
        escapeCSVCell(c.topic),
        escapeCSVCell(c.message)
      ]);
    });

    subscribers.forEach((s) => {
      rows.push([
        escapeCSVCell('Newsletter Lead'),
        escapeCSVCell(s.id),
        escapeCSVCell(s.timestamp),
        escapeCSVCell('—'),
        escapeCSVCell(s.email),
        escapeCSVCell(s.source),
        escapeCSVCell('Subscribed to Student Community Updates')
      ]);
    });

    const csv = [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    triggerDownload(csv, `kortex_all_leads_${new Date().toISOString().split('T')[0]}.csv`);
  }

  function clearAllData() {
    if (confirm('Are you sure you want to delete all stored submissions? This action is permanent.')) {
      localStorage.removeItem(STORAGE_KEY_CONTACT);
      localStorage.removeItem(STORAGE_KEY_NEWSLETTER);
      alert('Database cleared.');
      window.location.reload();
    }
  }

  function getRawContactSubmissions() {
    return getStoredItems(STORAGE_KEY_CONTACT);
  }

  function getRawNewsletterSubscribers() {
    return getStoredItems(STORAGE_KEY_NEWSLETTER);
  }

  // Scoped to window.KortexSecurityEngine with KortexStorage alias
  const securityEngine = {
    saveContactMessage,
    saveNewsletterEmail,
    getStats,
    getRawContactSubmissions,
    getRawNewsletterSubscribers,
    exportContactCSV,
    exportNewsletterCSV,
    exportAllCSV,
    clearAllData
  };

  window.KortexSecurityEngine = securityEngine;
  window.KortexStorage = securityEngine;
})();
