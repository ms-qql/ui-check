import React from "react";
import content from "./content.json";

import MeridianNav from "../../blocks/meridian-nav.jsx";
import MeridianHero from "../../blocks/meridian-hero.jsx";
import MeridianGlance from "../../blocks/meridian-glance.jsx";
import MeridianBulletin from "../../blocks/meridian-bulletin.jsx";
import MeridianFlow from "../../blocks/meridian-flow.jsx";
import MeridianIncidents from "../../blocks/meridian-incidents.jsx";
import MeridianTestimonials from "../../blocks/meridian-testimonials.jsx";
import MeridianCompare from "../../blocks/meridian-compare.jsx";
import MeridianIsland from "../../blocks/meridian-island.jsx";
import MeridianLogos from "../../blocks/meridian-logos.jsx";
import MeridianPricing from "../../blocks/meridian-pricing.jsx";
import MeridianFooter from "../../blocks/meridian-footer.jsx";

const BLOCKS = {
  "meridian-nav": MeridianNav,
  "meridian-hero": MeridianHero,
  "meridian-glance": MeridianGlance,
  "meridian-bulletin": MeridianBulletin,
  "meridian-flow": MeridianFlow,
  "meridian-incidents": MeridianIncidents,
  "meridian-testimonials": MeridianTestimonials,
  "meridian-compare": MeridianCompare,
  "meridian-island": MeridianIsland,
  "meridian-logos": MeridianLogos,
  "meridian-pricing": MeridianPricing,
  "meridian-footer": MeridianFooter,
};

/*
 * Kompositions-Entry: mappt content.json.sections[].block → Registry-Block,
 * reicht die Sektion als `data` hinein (Section-id-Contract: jede Sektion
 * rendert id={id}). Meridian ist dunkel-default → Wrapper bg-ink text-paper.
 */
export default function App({ content: c = content }) {
  return (
    <div className="min-h-screen bg-ink text-paper antialiased">
      {c.sections.map((s) => {
        const Block = BLOCKS[s.block];
        return Block ? <Block key={s.id} data={s} /> : null;
      })}
    </div>
  );
}
