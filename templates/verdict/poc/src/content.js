// Inhalt 1:1 aus der Vercel-Referenz (Clean-Room-Nachbau, nur zum Fidelity-Vergleich).
const A = "./assets";

export const nav = {
  links: ["About", "Services", "Case Studies", "Blog"],
  cta: "Book Free Consultation",
};

export const hero = {
  eyebrow: "When the result matters.",
  title: "Trusted legal help when it matters most.",
  bullets: ["Senior lawyers on every case", "Proven results in court", "Clear fees, no surprises"],
  ctas: [{ label: "Book a consultation", variant: "invert" }, { label: "See our services", variant: "ghostDark" }],
  bg: `${A}/hero/office.webp`,
  scroll: "Where good outcomes begin.",
  trustedBy: "Trusted by our clients",
  avatars: [`${A}/hero-avatars/av-1.jpg`, `${A}/hero-avatars/av-2.jpg`, `${A}/hero-avatars/av-3.jpg`, `${A}/hero-avatars/av-4.jpg`],
  stats: [
    { value: "1,800+", label: "Cases won" },
    { value: "22", label: "Years of experience" },
    { value: "1,000+", label: "Clients helped" },
  ],
};

export const about = {
  eyebrow: "About Us",
  title: "Honest, experienced lawyers for the moments that matter most.",
  body: "Our team brings decades of courtroom experience to every case. From major lawsuits to day-to-day legal questions, we build the strategy, evidence, and arguments that win — for founders, business leaders, and families facing important decisions.",
  cta: "Learn more",
  image: `${A}/about/team.webp`,
  imageTitle: "1,000+ clients served worldwide",
  imageSub: "Helping businesses in 15+ countries",
  imageCta: "Read reviews",
  metrics: [
    { value: "92%", label: "Cases won", sub: "for our clients" },
    { value: "75+", label: "Compliance checks", sub: "every year" },
    { value: "$1.2B", label: "Client money", sub: "protected and recovered" },
    { value: "380+", label: "Business contracts", sub: "drafted and signed" },
  ],
  rating: "4.9",
  reviewLogos: [
    { src: `${A}/reviews/google.svg`, alt: "Google", h: "h-5" },
    { src: `${A}/reviews/yelp.svg`, alt: "Yelp", h: "h-4" },
    { src: `${A}/reviews/avvo.svg`, alt: "Avvo", h: "h-4" },
    { src: `${A}/reviews/martindale.svg`, alt: "Martindale", h: "h-3.5" },
  ],
};

export const services = {
  eyebrow: "Our Services",
  title: "Trusted legal services across five key areas",
  body: "Every business hits moments where good legal advice really matters. Our five service areas are each led by senior lawyers — ready to protect what's yours and help you plan what's next.",
  hint: "— Hover to preview. Click to select.",
  items: [
    { num: "I", vol: "01", name: "Business Law", desc: "Contracts, deals, partnerships, and everyday legal help to keep your business running smoothly.", image: `${A}/services/i-corporate.webp` },
    { num: "II", vol: "02", name: "Lawsuits & Disputes", desc: "Strong defense for business disputes, regulator cases, and group lawsuits — from the first filing to the final ruling.", image: `${A}/services/ii-litigation.webp` },
    { num: "III", vol: "03", name: "Compliance & Rules", desc: "Clear plans, regulator support, and steady guidance to keep your business on the right side of the law.", image: `${A}/services/iii-compliance.webp` },
    { num: "IV", vol: "04", name: "Intellectual Property", desc: "Patents, trade secrets, brand protection, and licensing for the ideas that make your business valuable.", image: `${A}/services/iv-ip.webp` },
    { num: "V", vol: "05", name: "Restructuring & Recovery", desc: "Bankruptcy support, out-of-court deals, and creditor protection for businesses going through hard times.", image: `${A}/services/v-restructuring.webp` },
  ],
};

export const cases = {
  eyebrow: "Featured Case Studies",
  title: "Real cases. Real results for our clients.",
  body: "A look at recent work across our service areas. Some names are kept private to respect client confidentiality. These are the cases we were hired to win — and what the court decided.",
  cta: "See all case studies",
  items: [
    { num: "01", year: "2024", tags: ["Energy & Industry", "Class-Action Defense"], title: "Helped a large energy company defeat a price-fixing lawsuit brought by a group of its customers.", result: "The court refused to group the customers into a class, and threw the case out for good.", court: "Federal Court, New York", image: `${A}/cases/01-energy.webp` },
    { num: "02", year: "2025", tags: ["Technology", "Patent Defense"], title: "Defended a US tech company against a patent troll trying to block its products from the US market.", result: "No products were blocked, and we settled on terms that worked for our client.", court: "US Trade Commission", image: `${A}/cases/04-tech.webp` },
    { num: "03", year: "2024", tags: ["Media & Entertainment", "Copyright Trial"], title: "Took a film studio's copyright case to trial against a streaming company that used its content.", result: "The jury sided with our client and awarded $312 million.", court: "Federal Court, California", image: `${A}/cases/06-media.webp` },
    { num: "04", year: "2024", tags: ["Banking", "Restructuring"], title: "Represented a group of senior lenders in a large bankruptcy that spanned the US and UK.", result: "Our clients recovered the full $1.2 billion they were owed — and a little more.", court: "US & UK Courts", image: `${A}/cases/03-banking.webp` },
  ],
};

export const process = {
  eyebrow: "Our Process",
  title: "Five clear steps from first call to final result.",
  body: "Five steps. Same care, every case. The same senior team is with you from the very first call all the way to the result.",
  steps: [
    { n: "1", name: "First call", desc: "A senior lawyer takes your call — never an assistant. We listen, ask the right questions, and decide together if we're the right fit for your case.", image: `${A}/process/001-intake.webp` },
    { n: "2", name: "Strategy", desc: "We map the facts, the risks, and the fastest route to the outcome you need — and put it in writing.", image: `${A}/process/002-strategy.webp` },
    { n: "3", name: "Preparation", desc: "Evidence, documents, and arguments — built and stress-tested long before anyone steps into a courtroom.", image: `${A}/process/003-discovery.webp` },
    { n: "4", name: "Pre-trial", desc: "We push for the strongest possible position: motions, negotiations, and settlement when it serves you.", image: `${A}/process/004-pretrial.webp` },
    { n: "5", name: "Final result", desc: "The same senior team argues your case through to the verdict — and stands by the outcome.", image: `${A}/process/005-verdict.webp` },
  ],
};

export const team = {
  eyebrow: "Our Team",
  title: "The people behind your legal success.",
  body: "Every case is led by a senior lawyer — from the first call all the way to the result. Meet the team that proudly carries our firm's name.",
  cta: "Connect with us",
  members: [
    { name: "Jane Anderson", role: "Managing Partner", image: `${A}/partners/01-anderson.webp` },
    { name: "Marcus Klein", role: "Partner", image: `${A}/partners/02-klein.webp` },
    { name: "Rachel Lee", role: "Partner", image: `${A}/partners/03-lee.webp` },
    { name: "Tom Singh", role: "Partner", image: `${A}/partners/04-singh.webp` },
    { name: "Anna Petrova", role: "Partner", image: `${A}/partners/05-petrova.webp` },
    { name: "Daniel Okonkwo", role: "Partner", image: `${A}/partners/06-okonkwo.webp` },
  ],
};

export const awards = {
  eyebrow: "Our Awards",
  title: "Awards that reflect our work.",
  body: "Top rankings from the guides that lawyers actually trust — earned year after year.",
  image: `${A}/awards/01-chambers.webp`,
  items: [
    { n: "01", name: "Chambers USA — Top Rated for Lawsuits", year: "2024" },
    { n: "02", name: "The Legal 500 — Top Tier in Finance Law", year: "2024" },
    { n: "03", name: "Benchmark Litigation — Top Tier Firm", year: "2025" },
    { n: "04", name: "The American Lawyer — Litigation Team of the Year", year: "2024" },
    { n: "05", name: "Law360 — Practice Group of the Year", year: "2023" },
  ],
};

export const testimonials = {
  eyebrow: "Testimonials",
  title: "What our clients say.",
  body: "Most of our work stays private. With permission, these are some of the clients we've helped — in their own words.",
  // Bento-Grid: 5 Spalten × 3 Reihen (an das Original angelehnt)
  cells: [
    { type: "photo", image: `${A}/testimonials/client-01.webp`, col: "col-span-1", row: "row-span-1" },
    { type: "empty" },
    { type: "quote", quote: "Honest from day one.", tag: "Technology" },
    { type: "stat", label: "Recovered", value: "$1.2B", meta: "New York · 2024", accent: true },
    { type: "photo", image: `${A}/testimonials/client-02.webp` },
    { type: "empty" },
    { type: "photo", image: `${A}/testimonials/result-scene.webp`, caption: "Federal · D.C." },
    { type: "empty" },
    { type: "photo", image: `${A}/testimonials/client-05.webp` },
    { type: "empty" },
    { type: "quote", quote: "Ready in two weeks.", tag: "Life Sciences", dark: true },
    { type: "stat", label: "Court wins", value: "47", meta: "At trial", dark: true },
    { type: "empty" },
    { type: "empty" },
    { type: "stat", label: "Senior-led", value: "100%", meta: "Every case" },
  ],
};

export const faq = {
  eyebrow: "FAQ",
  title: "Answers to your legal questions.",
  body: "We know legal questions can feel a lot to handle — especially when you're not sure where to start. Here are the questions clients ask us most often before getting in touch.",
  footPrompt: "Don't see your question?",
  footCta: "Talk to a lawyer directly",
  items: [
    { q: "How does our first meeting work?", a: "A senior partner takes the first call — never an assistant. We use the call to check for conflicts, understand your case, and decide together if we're the right fit. The first conversation is free." },
    { q: "What will it be like working with our team?", a: "You work directly with a senior lawyer from start to finish — the same person who took your first call argues your case." },
    { q: "How long do different types of cases take?", a: "It depends on the matter. We give you an honest timeline at the start and update you at every milestone." },
    { q: "How does pricing and billing work?", a: "Clear fees agreed up front — no surprises. We explain exactly what you're paying for before any work begins." },
    { q: "How do we keep your information safe?", a: "Everything you share is private and secure, handled under strict attorney-client confidentiality." },
    { q: "Do we handle appeals and follow-up work?", a: "Yes. The same senior team stays with you through appeals and any follow-up the outcome requires." },
  ],
};

export const contact = {
  eyebrow: "Contact",
  title: "Talk to a lawyer.",
  body: "A senior lawyer takes the call. Conflicts checked within the hour, and a clear plan in your inbox within three days.",
  formEyebrow: "Private & secure",
  formTitle: "Tell us about your case.",
  fields: {
    name: { label: "Name", placeholder: "Your full name" },
    email: { label: "Email", placeholder: "you@email.com" },
    caseType: { label: "Type of case", placeholder: "Pick a case type" },
    location: { label: "Location", placeholder: "Pick a location" },
    message: { label: "Your message", placeholder: "A short note about your case. Kept private." },
  },
  submit: "Send message",
  cardEyebrow: "Start your case",
  cardTitle: "Ready to get started?",
  contacts: [
    { label: "Email", value: "counsel@verdict.law" },
    { label: "Direct", value: "+1 (212) 555-0142" },
    { label: "Office", value: "One Liberty Plaza, New York" },
  ],
};

export const footer = {
  tagline: "We do the work to know — and to say — what others are still trying to figure out.",
  firm: { title: "Firm", links: ["About", "Services", "Case studies", "Blog", "Contact"] },
  offices: {
    title: "Offices",
    items: [
      { city: "New York", addr: "One Liberty Plaza, New York, NY 10006" },
      { city: "Washington, D.C.", addr: "900 17th Street NW, Washington, D.C. 20006" },
      { city: "London", addr: "30 St Mary Axe, London EC3A 8BF" },
    ],
  },
  contact: { title: "Contact", links: ["counsel@verdict.law", "+1 (212) 555-0142", "LinkedIn", "Chambers"] },
  legal: "© Verdict LLP · Attorney advertising",
  license: "Licensed in New York & Washington D.C.",
};
