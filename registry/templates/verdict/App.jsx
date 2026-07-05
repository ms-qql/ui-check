import React from "react";
import content from "./content.json";

import VerdictNav from "../../blocks/verdict-nav.jsx";
import VerdictHero from "../../blocks/verdict-hero.jsx";
import VerdictAbout from "../../blocks/verdict-about.jsx";
import VerdictServices from "../../blocks/verdict-services.jsx";
import VerdictCases from "../../blocks/verdict-cases.jsx";
import VerdictProcess from "../../blocks/verdict-process.jsx";
import VerdictTeam from "../../blocks/verdict-team.jsx";
import VerdictAwards from "../../blocks/verdict-awards.jsx";
import VerdictTestimonials from "../../blocks/verdict-testimonials.jsx";
import VerdictFaq from "../../blocks/verdict-faq.jsx";
import VerdictContact from "../../blocks/verdict-contact.jsx";
import VerdictFooter from "../../blocks/verdict-footer.jsx";

const BLOCKS = {
  "verdict-nav": VerdictNav,
  "verdict-hero": VerdictHero,
  "verdict-about": VerdictAbout,
  "verdict-services": VerdictServices,
  "verdict-cases": VerdictCases,
  "verdict-process": VerdictProcess,
  "verdict-team": VerdictTeam,
  "verdict-awards": VerdictAwards,
  "verdict-testimonials": VerdictTestimonials,
  "verdict-faq": VerdictFaq,
  "verdict-contact": VerdictContact,
  "verdict-footer": VerdictFooter,
};

/*
 * Kompositions-Entry: mappt content.json.sections[].block → Registry-Block,
 * reicht die Sektion als `data` hinein (Section-id-Contract: jede Sektion
 * rendert id={id}). Dient zugleich als Vorlage für den ui-redesign-App.jsx.
 */
export default function App({ content: c = content }) {
  return (
    <div className="min-h-screen bg-paper text-ink antialiased">
      {c.sections.map((s) => {
        const Block = BLOCKS[s.block];
        return Block ? <Block key={s.id} data={s} /> : null;
      })}
    </div>
  );
}
