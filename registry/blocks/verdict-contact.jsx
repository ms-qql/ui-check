import React from "react";
import { Eyebrow, Button } from "../lib/ui.jsx";

/*
 * verdict-contact — Kontakt-Sektion: Formular + Amber-Gradient-Card.
 * Section-Typ: contact.  Keine Bild-Slots.
 * Props: { data } — Felder: title, body, formEyebrow, formTitle, fields,
 *   submit, cardEyebrow, cardTitle, contacts.
 */
function FieldLabel({ children }) {
  return (
    <div className="mono-label mb-2 flex items-center gap-2 text-muted">
      <span className="h-px w-4 bg-accent" /> {children} <span className="text-accent">*</span>
    </div>
  );
}
const inputCls = "w-full rounded-lg border border-transparent bg-surface px-4 py-3 text-sm text-ink placeholder:text-muted focus:border-accent focus:outline-none";

export default function VerdictContact({ data = {} }) {
  const {
    id = "contact",
    title, body, formEyebrow, formTitle, fields = {}, submit,
    cardEyebrow, cardTitle, contacts = [],
  } = data;
  const f = fields;
  return (
    <section id={id} className="section-padding">
      <div className="container-x">
        <div className="mb-14 text-center">
          <div className="mb-6 flex justify-start"><Eyebrow>Contact</Eyebrow></div>
          <h2 className="display mx-auto max-w-xl text-[clamp(2rem,4.8vw,3.75rem)]">{title}</h2>
          <p className="mx-auto mt-6 max-w-lg text-[1.05rem] leading-relaxed text-muted">{body}</p>
        </div>

        <div className="grid gap-8 lg:grid-cols-2">
          {/* Formular */}
          <div className="rounded-3xl border border-line p-8 md:p-10">
            <div className="mono-label flex items-center gap-2 text-muted">
              <span className="h-px w-6 bg-accent" /> {formEyebrow}
            </div>
            <h3 className="mt-4 text-2xl font-medium md:text-3xl">{formTitle}</h3>
            <form className="mt-8 grid gap-6 sm:grid-cols-2" onSubmit={(e) => e.preventDefault()}>
              <div><FieldLabel>{f.name?.label}</FieldLabel><input className={inputCls} placeholder={f.name?.placeholder} /></div>
              <div><FieldLabel>{f.email?.label}</FieldLabel><input className={inputCls} placeholder={f.email?.placeholder} /></div>
              <div>
                <FieldLabel>{f.caseType?.label}</FieldLabel>
                <select className={inputCls} defaultValue=""><option value="" disabled>{f.caseType?.placeholder}</option><option>Business Law</option><option>Litigation</option></select>
              </div>
              <div>
                <FieldLabel>{f.location?.label}</FieldLabel>
                <select className={inputCls} defaultValue=""><option value="" disabled>{f.location?.placeholder}</option><option>New York</option><option>London</option></select>
              </div>
              <div className="sm:col-span-2">
                <FieldLabel>{f.message?.label}</FieldLabel>
                <textarea rows={3} className={inputCls} placeholder={f.message?.placeholder} />
              </div>
              <Button type="submit" className="sm:col-span-2 self-start">{submit} ↗</Button>
            </form>
          </div>

          {/* Amber-Card */}
          <div className="relative flex flex-col overflow-hidden rounded-3xl p-8 text-paper md:p-10 bg-gradient-to-br from-accent via-accent-soft to-ink">
            <div className="mono-label flex items-center gap-2 text-paper/70">
              <span className="h-px w-6 bg-paper/60" /> {cardEyebrow}
            </div>
            <h3 className="display mt-4 text-[clamp(2rem,4vw,3rem)]">{cardTitle}</h3>
            <dl className="mt-auto space-y-0 pt-16">
              {contacts.map((c) => (
                <div key={c.label} className="flex items-center justify-between border-t border-paper/20 py-4">
                  <dt className="mono-label text-paper/60">{c.label}</dt>
                  <dd className="text-sm">{c.value}</dd>
                </div>
              ))}
            </dl>
          </div>
        </div>
      </div>
    </section>
  );
}
