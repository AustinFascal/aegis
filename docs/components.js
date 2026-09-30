/**
 * AEGIS - Reusable Header and Footer Web Components
 * Enables single-source-of-truth navigation and footer across all pages.
 */

class AegisHeader extends HTMLElement {
  connectedCallback() {
    const activePage = this.getAttribute('active-page') || 'home';
    const isDownload = activePage === 'download' || window.location.pathname.includes('/download');
    const root = this.getAttribute('base-path') || (isDownload ? '../' : './');

    const homeUrl = isDownload ? `${root}index.html` : '';
    const downloadUrl = isDownload ? '#' : `${root}download/`;
    const logoSrc = `${root}assets/images/aegis_logo.png`;

    this.innerHTML = `
    <header class="site-header">
      <div class="container">
        <nav class="navbar" aria-label="Main Navigation">
          <a href="${homeUrl}#hero" class="nav-brand" id="navBrand">
            <img src="${logoSrc}" alt="Aegis Crest Logo" class="brand-logo-img">
            <span class="brand-text">AEGIS</span>
          </a>

          <ul class="nav-menu" id="navMenu">
            <li><a href="${homeUrl}#features" class="nav-link ${activePage === 'features' ? 'active' : ''}">Features</a></li>
            <li><a href="${downloadUrl}" class="nav-link ${activePage === 'download' ? 'active' : ''}">Download</a></li>
            <li><a href="${homeUrl}#architecture" class="nav-link ${activePage === 'architecture' ? 'active' : ''}">Architecture</a></li>
            <li><a href="${homeUrl}#deployment" class="nav-link ${activePage === 'deployment' ? 'active' : ''}">Agent Setup</a></li>
            <li><a href="${homeUrl}#faq" class="nav-link ${activePage === 'faq' ? 'active' : ''}">FAQ</a></li>
            <li class="nav-menu-mobile-extra">
              <a href="https://github.com/AustinFascal/aegis" target="_blank" rel="noopener noreferrer" class="btn btn-secondary btn-sm" style="width: 100%; justify-content: center; gap: 8px;">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
                </svg>
                <span>GitHub Repository</span>
              </a>
            </li>
          </ul>

          <div class="nav-actions">
            <a href="${downloadUrl}" class="btn btn-primary btn-sm nav-download-btn">
              <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
              </svg>
              <span>Download</span>
            </a>
            <a href="https://github.com/AustinFascal/aegis" target="_blank" rel="noopener noreferrer" class="btn btn-secondary btn-sm nav-github-btn" id="githubRepoBtn">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
              </svg>
              <span>GitHub</span>
            </a>
            <button class="mobile-toggle" id="mobileToggle" aria-label="Toggle Navigation Menu" aria-expanded="false">
              <span class="hamburger-bar"></span>
              <span class="hamburger-bar"></span>
              <span class="hamburger-bar"></span>
            </button>
          </div>
        </nav>
      </div>
    </header>
    `;

    this.initInteractions();
  }

  initInteractions() {
    const mobileToggle = this.querySelector('#mobileToggle');
    const navMenu = this.querySelector('#navMenu');
    const header = this.querySelector('.site-header');

    if (mobileToggle && navMenu) {
      const toggleMenu = (forceState) => {
        const isOpen = typeof forceState === 'boolean' ? forceState : !navMenu.classList.contains('open');
        navMenu.classList.toggle('open', isOpen);
        mobileToggle.classList.toggle('active', isOpen);
        mobileToggle.setAttribute('aria-expanded', isOpen);
      };

      mobileToggle.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleMenu();
      });

      // Close menu when a link is clicked
      navMenu.querySelectorAll('.nav-link, a').forEach(link => {
        link.addEventListener('click', () => toggleMenu(false));
      });

      // Close menu when clicking outside
      document.addEventListener('click', (e) => {
        if (navMenu.classList.contains('open') && !this.contains(e.target)) {
          toggleMenu(false);
        }
      });

      // Close on Escape key
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && navMenu.classList.contains('open')) {
          toggleMenu(false);
        }
      });

      // Close on window resize above mobile breakpoint
      window.addEventListener('resize', () => {
        if (window.innerWidth > 768 && navMenu.classList.contains('open')) {
          toggleMenu(false);
        }
      });
    }

    if (header) {
      window.addEventListener('scroll', () => {
        if (window.scrollY > 40) {
          header.classList.add('scrolled');
        } else {
          header.classList.remove('scrolled');
        }
      });
    }
  }
}
customElements.define('aegis-header', AegisHeader);

class AegisFooter extends HTMLElement {
  connectedCallback() {
    const activePage = this.getAttribute('active-page') || (window.location.pathname.includes('/download') ? 'download' : 'home');
    const isDownload = activePage === 'download';
    const root = this.getAttribute('base-path') || (isDownload ? '../' : './');

    const homeUrl = isDownload ? `${root}index.html` : '';
    const downloadUrl = isDownload ? '#' : `${root}download/`;
    const logoSrc = `${root}assets/images/aegis_logo.png`;

    this.innerHTML = `
    <footer class="site-footer">
      <div class="container">
        <div class="footer-top">
          <div class="footer-brand-info">
            <div style="display: flex; align-items: center; gap: 10px;">
              <img src="${logoSrc}" alt="Aegis Logo" style="width: 28px; height: 28px;">
              <span style="font-family: var(--font-heading); font-size: 1.2rem; font-weight: 800; color: #FFF;">AEGIS</span>
            </div>
            <p class="footer-desc">
              Automated Enterprise Guardian for Infrastructure Systems. Next-generation zero-trust telemetry, real-time threat intelligence & server hardening client.
            </p>
          </div>

          <div>
            <div class="footer-col-title">Navigation</div>
            <ul class="footer-links">
              <li><a href="${homeUrl}#hero">Overview</a></li>
              <li><a href="${homeUrl}#features">Features</a></li>
              <li><a href="${homeUrl}#sandbox">Interactive Demo</a></li>
              <li><a href="${downloadUrl}">Download Client</a></li>
            </ul>
          </div>

          <div>
            <div class="footer-col-title">Resources</div>
            <ul class="footer-links">
              <li><a href="https://github.com/AustinFascal/aegis" target="_blank" rel="noopener noreferrer">GitHub Repository</a></li>
              <li><a href="https://github.com/AustinFascal/aegis/blob/main/README.md" target="_blank" rel="noopener noreferrer">Documentation</a></li>
              <li><a href="https://github.com/AustinFascal/aegis/issues" target="_blank" rel="noopener noreferrer">Issue Tracker</a></li>
              <li><a href="https://github.com/AustinFascal/aegis/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">License</a></li>
            </ul>
          </div>

          <div>
            <div class="footer-col-title">SecOps Tools</div>
            <ul class="footer-links">
              <li><a href="${homeUrl}#sandbox">VT100 Terminal</a></li>
              <li><a href="${homeUrl}#sandbox">SFTP File Manager</a></li>
              <li><a href="${homeUrl}#sandbox">AbuseIPDB Threat Radar</a></li>
              <li><a href="${homeUrl}#deployment">Python Agent</a></li>
            </ul>
          </div>
        </div>

        <div class="footer-bottom">
          <div class="footer-copyright">
            © ${new Date().getFullYear()} CethoKaryo • Created by Austin Fascal. All rights reserved.
          </div>
          <div class="footer-social-links" aria-label="Social Media Links">
            <a href="https://github.com/AustinFascal" target="_blank" rel="noopener noreferrer" class="social-icon-btn" title="GitHub Profile" aria-label="GitHub">
              <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
              </svg>
            </a>
            <a href="https://austinfascal.github.io/portfolio" target="_blank" rel="noopener noreferrer" class="social-icon-btn" title="Portfolio Website" aria-label="Portfolio">
              <svg width="17" height="17" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/>
              </svg>
            </a>
            <a href="https://linkedin.com/in/austinfascal" target="_blank" rel="noopener noreferrer" class="social-icon-btn" title="LinkedIn Profile" aria-label="LinkedIn">
              <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor">
                <path d="M19 3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14m-.5 15.5v-5.3a3.26 3.26 0 0 0-3.26-3.26c-.85 0-1.84.52-2.28 1.3v-1.11h-2.79v8.37h2.79v-4.93c0-.77.62-1.4 1.39-1.4a1.4 1.4 0 0 1 1.4 1.4v4.93h2.75M6.46 8.76c.94 0 1.7-.76 1.7-1.7s-.76-1.7-1.7-1.7-1.7.76-1.7 1.7.76 1.7 1.7 1.7m1.4 9.74v-8.37H5.06v8.37h2.8z"/>
              </svg>
            </a>
            <a href="https://x.com/fascal_austin" target="_blank" rel="noopener noreferrer" class="social-icon-btn" title="X (Twitter)" aria-label="X (Twitter)">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
              </svg>
            </a>
            <a href="mailto:austinfascaliskandar@gmail.com" class="social-icon-btn" title="Email Austin Fascal" aria-label="Email">
              <svg width="17" height="17" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
            </a>
          </div>
        </div>
      </div>
    </footer>
    `;
  }
}
customElements.define('aegis-footer', AegisFooter);
