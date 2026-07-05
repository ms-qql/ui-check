import React from "react";
import { content } from "./content.js";

import Nav from "./sections/Nav.jsx";
import Hero from "./sections/Hero.jsx";
import Glance from "./sections/Glance.jsx";
import Bulletin from "./sections/Bulletin.jsx";
import Flow from "./sections/Flow.jsx";
import Incidents from "./sections/Incidents.jsx";
import Testimonials from "./sections/Testimonials.jsx";
import Compare from "./sections/Compare.jsx";
import Island from "./sections/Island.jsx";
import Logos from "./sections/Logos.jsx";
import Pricing from "./sections/Pricing.jsx";
import Footer from "./sections/Footer.jsx";

export default function App() {
  return (
    <div className="min-h-screen bg-ink text-paper antialiased">
      <Nav data={content.nav} />
      <Hero data={content.hero} />
      <Glance data={content.glance} />
      <Bulletin data={content.bulletin} />
      <Flow data={content.flow} />
      <Incidents data={content.incidents} />
      <Testimonials data={content.testimonials} />
      <Compare data={content.compare} />
      <Island data={content.island} />
      <Logos data={content.logos} />
      <Pricing data={content.pricing} />
      <Footer data={content.footer} />
    </div>
  );
}
