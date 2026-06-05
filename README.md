# Vinnie's Oil Australia — GitHub Pages Website

Authorised Australian distributor of Vinnie's Oil — premium Swedish hardwax oils and waxes for timber.
Distributed by **THJP Enterprises Pty Ltd** ABN: 56 696 226 203.

## 🚀 Deploying to GitHub Pages

### Option 1 — New Repository (Recommended)
1. Create a new GitHub repository (e.g. `vinniesoil-au`)
2. Upload all files from this folder maintaining the directory structure
3. Go to **Settings → Pages**
4. Under **Source**, select **Deploy from a branch**
5. Choose `main` branch and `/ (root)` folder
6. Click **Save** — your site will be live at `https://yourusername.github.io/vinniesoil-au/`

### Option 2 — Custom Domain
1. Follow Option 1 steps above
2. In **Settings → Pages → Custom domain**, enter your domain (e.g. `vinniesoilaustralia.com`)
3. Add a `CNAME` file to the repo root containing just your domain name
4. Update your DNS: add a CNAME record pointing to `yourusername.github.io`

## 📁 File Structure

```
/                       ← Root (GitHub Pages serves from here)
├── index.html          ← Home page
├── css/
│   └── style.css       ← Global stylesheet (all pages share this)
├── js/
│   └── shared.js       ← Shared JavaScript (nav, accordion, tabs, etc.)
├── pages/
│   ├── story.html      ← The Vinnie's Oil Story
│   ├── about.html      ← About Us (Australia)
│   ├── products.html   ← Full product range listing
│   ├── product-upo.html
│   ├── product-upo-rustic.html
│   ├── product-eternal-seal.html
│   ├── product-monocoat.html
│   ├── product-hard-wax.html
│   ├── product-soft-wax.html
│   ├── retail-network.html
│   ├── resources.html
│   ├── contact.html
│   └── 404.html
├── _config.yml         ← GitHub Pages / Jekyll config
└── README.md           ← This file
```

## 🔗 Pages Included

| Page | URL |
|------|-----|
| Home | `/index.html` |
| The Story | `/pages/story.html` |
| About Us | `/pages/about.html` |
| All Products | `/pages/products.html` |
| Ultra Penetrating Oil | `/pages/product-upo.html` |
| UPO Rustic Dark | `/pages/product-upo-rustic.html` |
| Eternal Seal | `/pages/product-eternal-seal.html` |
| Universal Monocoat | `/pages/product-monocoat.html` |
| Hard Wax | `/pages/product-hard-wax.html` |
| Soft Wax | `/pages/product-soft-wax.html` |
| Retail Network | `/pages/retail-network.html` |
| Resources | `/pages/resources.html` |
| Contact Us | `/pages/contact.html` |

## ✏️ Customisation Notes

- **Logo**: Images are served from the live Vinnie's Oil Google Sites CDN. Replace URLs in nav/footer if hosting locally.
- **Contact form**: The form uses a `mailto:` fallback (GitHub Pages has no server). For a real form, integrate [Formspree](https://formspree.io) — replace the `<form>` action with `https://formspree.io/f/YOUR_ID`.
- **Formspree setup**: Sign up free at formspree.io → New Form → copy endpoint → set `action="https://formspree.io/f/xxxx"` and `method="POST"` on each `<form>` element.
- **Adding retailers**: Edit `pages/retail-network.html` and add retailer cards in the `#retailer-grid` div following the existing card pattern.
- **Colours**: All brand colours are CSS custom properties in `css/style.css` under `:root {}` — easy to update globally.

## 📋 Dependencies

- **Fonts**: Google Fonts (Outfit + Playfair Display) — loaded via CDN in each HTML `<head>`
- **Icons**: Inline SVG — no external icon library required
- **No frameworks**: Pure HTML, CSS and vanilla JavaScript — no build step, no Node.js, no dependencies

## 🏢 Business

**Vinnie's Oil Australia**
Operated by THJP Enterprises Pty Ltd
ABN: 56 696 226 203
Website: [vinniesoilaustralia.com](https://vinniesoilaustralia.com)
Email: info@vinniesoilaustralia.com

Vinnie's Oil is a registered brand of Vinnie's Oil Europe.
