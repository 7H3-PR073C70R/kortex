/**
 * KORTEX LEAD & SUBMISSION STORAGE ENGINE
 * Handles Contact Form submissions, Newsletter subscriptions,
 * LocalStorage persistence, and instant CSV Export (RFC 4180 compliant with UTF-8 BOM).
 */

(function () {
  const STORAGE_KEY_CONTACT = 'kortex_contact_submissions';
  const STORAGE_KEY_NEWSLETTER = 'kortex_newsletter_subscribers';

  // --------------------------------------------------------------------------
  // 1. Data Access & Mutators
  // --------------------------------------------------------------------------
  function getStoredItems(key) {
    try {
      const data = localStorage.getItem(key);
      return data ? JSON.parse(data) : [];
    } catch (e) {
      console.error('Failed to read from localStorage:', e);
      return [];
    }
  }

  function setStoredItems(key, items) {
    try {
      localStorage.setItem(key, JSON.stringify(items));
    } catch (e) {
      console.error('Failed to write to localStorage:', e);
    }
  }

  // Save a Contact Form Message
  function saveContactMessage({ name, email, topic, message, newsletterOptIn }) {
    const submissions = getStoredItems(STORAGE_KEY_CONTACT);
    const newEntry = {
      id: 'msg_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      timestamp: new Date().toISOString(),
      name: (name || '').trim(),
      email: (email || '').trim().toLowerCase(),
      topic: topic || 'general',
      message: (message || '').trim(),
      newsletterOptIn: !!newsletterOptIn
    };

    submissions.push(newEntry);
    setStoredItems(STORAGE_KEY_CONTACT, submissions);

    // If opted into newsletter, automatically register in subscribers list
    if (newsletterOptIn && newEntry.email) {
      saveNewsletterEmail(newEntry.email, 'contact_form_optin');
    }

    return newEntry;
  }

  // Save a Newsletter Subscription
  function saveNewsletterEmail(email, source = 'website') {
    const subscribers = getStoredItems(STORAGE_KEY_NEWSLETTER);
    const cleanEmail = (email || '').trim().toLowerCase();

    if (!cleanEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      throw new Error('Please enter a valid email address.');
    }

    // Deduplicate
    const existing = subscribers.find((s) => s.email === cleanEmail);
    if (existing) {
      return { status: 'already_subscribed', email: cleanEmail };
    }

    const newSubscriber = {
      id: 'sub_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      timestamp: new Date().toISOString(),
      email: cleanEmail,
      source: source || 'website'
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
  // 2. CSV Export Generator (RFC 4180 Compliant with UTF-8 BOM for Excel)
  // --------------------------------------------------------------------------
  function escapeCSV(field) {
    if (field === null || field === undefined) return '""';
    const str = String(field);
    if (str.includes('"') || str.includes(',') || str.includes('\n') || str.includes('\r')) {
      return '"' + str.replace(/"/g, '""') + '"';
    }
    return '"' + str + '"';
  }

  function downloadCSV(csvContent, filename) {
    // Add UTF-8 BOM for proper rendering in Microsoft Excel & Numbers
    const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  function exportContactCSV() {
    const items = getStoredItems(STORAGE_KEY_CONTACT);
    if (items.length === 0) {
      alert('No contact submissions recorded yet.');
      return;
    }

    const headers = ['ID', 'Timestamp (ISO)', 'Name', 'Email', 'Topic', 'Message', 'Newsletter Opt-In'];
    const rows = items.map((item) => [
      escapeCSV(item.id),
      escapeCSV(item.timestamp),
      escapeCSV(item.name),
      escapeCSV(item.email),
      escapeCSV(item.topic),
      escapeCSV(item.message),
      escapeCSV(item.newsletterOptIn ? 'Yes' : 'No')
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    const dateStr = new Date().toISOString().split('T')[0];
    downloadCSV(csvContent, `kortex_contact_submissions_${dateStr}.csv`);
  }

  function exportNewsletterCSV() {
    const items = getStoredItems(STORAGE_KEY_NEWSLETTER);
    if (items.length === 0) {
      alert('No newsletter subscribers recorded yet.');
      return;
    }

    const headers = ['ID', 'Timestamp (ISO)', 'Email', 'Acquisition Source'];
    const rows = items.map((item) => [
      escapeCSV(item.id),
      escapeCSV(item.timestamp),
      escapeCSV(item.email),
      escapeCSV(item.source)
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    const dateStr = new Date().toISOString().split('T')[0];
    downloadCSV(csvContent, `kortex_newsletter_subscribers_${dateStr}.csv`);
  }

  function exportAllCSV() {
    const contacts = getStoredItems(STORAGE_KEY_CONTACT);
    const subscribers = getStoredItems(STORAGE_KEY_NEWSLETTER);

    if (contacts.length === 0 && subscribers.length === 0) {
      alert('No records to export yet. Submit a message or subscribe first!');
      return;
    }

    const headers = ['Record Type', 'ID', 'Timestamp (ISO)', 'Name', 'Email', 'Topic / Source', 'Message / Notes'];
    const rows = [];

    contacts.forEach((c) => {
      rows.push([
        escapeCSV('Contact Message'),
        escapeCSV(c.id),
        escapeCSV(c.timestamp),
        escapeCSV(c.name),
        escapeCSV(c.email),
        escapeCSV(c.topic),
        escapeCSV(c.message)
      ]);
    });

    subscribers.forEach((s) => {
      rows.push([
        escapeCSV('Newsletter Subscriber'),
        escapeCSV(s.id),
        escapeCSV(s.timestamp),
        escapeCSV('—'),
        escapeCSV(s.email),
        escapeCSV(s.source),
        escapeCSV('Subscribed to Development Dispatches')
      ]);
    });

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    const dateStr = new Date().toISOString().split('T')[0];
    downloadCSV(csvContent, `kortex_all_leads_export_${dateStr}.csv`);
  }

  function clearAllData() {
    if (confirm('Are you sure you want to clear all locally stored submissions and subscribers? This cannot be undone.')) {
      localStorage.removeItem(STORAGE_KEY_CONTACT);
      localStorage.removeItem(STORAGE_KEY_NEWSLETTER);
      alert('All local submissions have been cleared.');
      window.location.reload();
    }
  }

  // Export globally for page scripts
  window.KortexStorage = {
    saveContactMessage,
    saveNewsletterEmail,
    getStats,
    exportContactCSV,
    exportNewsletterCSV,
    exportAllCSV,
    clearAllData
  };
})();
