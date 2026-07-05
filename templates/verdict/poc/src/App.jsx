import React from "react";
import Nav from "./sections/Nav.jsx";
import Hero from "./sections/Hero.jsx";
import About from "./sections/About.jsx";
import Services from "./sections/Services.jsx";
import Cases from "./sections/Cases.jsx";
import Process from "./sections/Process.jsx";
import Team from "./sections/Team.jsx";
import Awards from "./sections/Awards.jsx";
import Testimonials from "./sections/Testimonials.jsx";
import Faq from "./sections/Faq.jsx";
import Contact from "./sections/Contact.jsx";
import Footer from "./sections/Footer.jsx";

export default function App() {
  return (
    <div className="min-h-screen bg-paper text-ink antialiased">
      <Nav />
      <main>
        <Hero />
        <About />
        <Services />
        <Cases />
        <Process />
        <Team />
        <Awards />
        <Testimonials />
        <Faq />
        <Contact />
      </main>
      <Footer />
    </div>
  );
}
