import { gsap } from "gsap";

/** Reversible product storytelling; all effects are scoped to this media context. */
export function createScrollScenes() {
  const media = gsap.matchMedia();
  document.documentElement.classList.add("has-motion");
  media.add(
    {
      compact: "(max-width: 960px)",
      wide: "(min-width: 961px)",
      tall: "(min-height: 651px)",
    },
    (context) => {
      const compact = !!context.conditions?.compact;
      const tall = !!context.conditions?.tall;
      gsap.from(".title-mask > span", {
        yPercent: 110,
        duration: 0.8,
        stagger: 0.09,
        ease: "power4.out",
      });
      gsap.from(".phone-arrival", {
        y: 100,
        scale: 0.65,
        opacity: 0,
        duration: 1,
        ease: "power3.out",
      });
      const reveal = (target: string, from: gsap.TweenVars, trigger = target) =>
        gsap.fromTo(target, from, {
          y: 0,
          x: 0,
          scale: 1,
          rotation: 0,
          opacity: 1,
          clipPath: "inset(0% 0% 0% 0%)",
          ease: "power2.out",
          scrollTrigger: {
            trigger,
            start: "top 95%",
            end: "top 32%",
            scrub: true,
            invalidateOnRefresh: true,
          },
        });
      reveal("#features .section-heading h2", {
        y: 85,
        clipPath: "inset(0% 0% 90% 0%)",
      });
      gsap.fromTo(
        ".detail-preview",
        { y: 160, scale: 0.72, rotation: -14, clipPath: "inset(0% 0% 24% 0%)" },
        {
          y: 0,
          scale: 1,
          rotation: 4,
          clipPath: "inset(0% 0% 0% 0%)",
          ease: "power2.out",
          scrollTrigger: {
            trigger: ".note-scene",
            start: "top 95%",
            end: "top 22%",
            scrub: true,
            invalidateOnRefresh: true,
          },
        },
      );
      gsap.fromTo(
        ".note-shadow",
        { rotation: 14 },
        {
          rotation: -9,
          ease: "none",
          scrollTrigger: {
            trigger: ".note-scene",
            start: "top 95%",
            end: "top 22%",
            scrub: true,
          },
        },
      );
      gsap.utils.toArray<HTMLElement>(".feature-copy").forEach((copy) => {
        gsap.fromTo(
          copy,
          { y: 70, opacity: 0.35 },
          {
            y: 0,
            opacity: 1,
            ease: "power2.out",
            scrollTrigger: {
              trigger: copy,
              start: "top 94%",
              end: "top 55%",
              scrub: true,
            },
          },
        );
      });
      gsap.utils
        .toArray<HTMLElement>(".choice-label")
        .forEach((label, index) => {
          gsap.fromTo(
            label,
            {
              x: index % 2 ? 160 : -160,
              y: 60,
              rotation: index % 2 ? 22 : -22,
              opacity: 0.15,
            },
            {
              x: 0,
              y: 0,
              rotation: index === 2 ? -3 : index % 2 ? 8 : -9,
              opacity: 1,
              ease: "power2.out",
              scrollTrigger: {
                trigger: ".choice-scene",
                start: `top ${96 - index * 6}%`,
                end: `top ${42 - index * 5}%`,
                scrub: true,
              },
            },
          );
        });
      reveal(".plan-visual", {
        y: 150,
        scale: 0.7,
        rotation: 12,
        clipPath: "inset(0% 0% 30% 0%)",
      });
      gsap.utils.toArray<HTMLElement>(".steps li").forEach((step, index) => {
        gsap.fromTo(
          step,
          { y: 120, rotation: index % 2 ? 5 : -5, scale: 0.94 },
          {
            y: 0,
            rotation: 0,
            scale: 1,
            ease: "power2.out",
            scrollTrigger: {
              trigger: step,
              start: "top 96%",
              end: "top 45%",
              scrub: true,
              invalidateOnRefresh: true,
            },
          },
        );
      });
      gsap.fromTo(
        ".reuse-wheel",
        { rotation: -60 },
        {
          rotation: 120,
          ease: "none",
          scrollTrigger: {
            trigger: ".reuse-art",
            start: "top bottom",
            end: "bottom top",
            scrub: true,
          },
        },
      );
      reveal(
        ".reuse-note-one",
        { x: -140, y: 70, rotation: -25 },
        ".reuse-art",
      );
      reveal(".reuse-note-two", { x: 140, y: 90, rotation: 25 }, ".reuse-art");
      gsap.utils
        .toArray<HTMLElement>(
          ".requirements h2, .download-grid h2, .faq-section h2, .privacy-section h2, .closing p",
        )
        .forEach((heading) => {
          gsap.from(heading, {
            y: 55,
            opacity: 0.3,
            duration: 0.7,
            ease: "power3.out",
            scrollTrigger: { trigger: heading, start: "top 92%", once: true },
          });
        });
      gsap.fromTo(
        ".closing-word",
        { yPercent: 45, rotation: 6, scale: 0.8 },
        {
          yPercent: 0,
          rotation: 0,
          scale: 1,
          ease: "power2.out",
          scrollTrigger: {
            trigger: ".closing",
            start: "top 85%",
            end: "bottom bottom",
            scrub: true,
          },
        },
      );
      if (tall) {
        const opening = gsap.timeline({
          scrollTrigger: {
            trigger: ".hero",
            start: "top top+=80",
            end: "bottom bottom",
            scrub: true,
            invalidateOnRefresh: true,
          },
        });
        opening
          .to(
            ".phone-motion",
            {
              rotation: 0,
              scale: 1.15,
              y: compact ? -24 : 0,
              x: () => (compact ? 0 : -innerWidth * 0.18),
              ease: "power1.inOut",
              duration: 1,
            },
            0,
          )
          .to(
            ".hero-copy",
            { y: -90, autoAlpha: 0, ease: "power1.in", duration: 0.5 },
            0,
          )
          .to(".scene-disc", { scale: 1.35, opacity: 0.35, duration: 1 }, 0)
          .to(
            ".scene-path",
            { rotation: 65, scale: 1.2, opacity: 0, duration: 1 },
            0,
          )
          .to(
            ".slip-one",
            {
              x: compact ? 115 : 200,
              y: 160,
              rotation: 0,
              scale: 0.7,
              opacity: 0,
              duration: 0.8,
            },
            0.05,
          )
          .to(
            ".slip-two",
            {
              x: compact ? -105 : -230,
              y: -30,
              rotation: 0,
              scale: 0.7,
              opacity: 0,
              duration: 0.8,
            },
            0.1,
          )
          .to(
            ".slip-three",
            {
              x: compact ? 90 : 180,
              y: -140,
              rotation: 0,
              scale: 0.7,
              opacity: 0,
              duration: 0.8,
            },
            0.15,
          )
          .fromTo(
            ".hero-resolution",
            { y: 70, autoAlpha: 0 },
            { y: 0, autoAlpha: 1, duration: 0.35 },
            0.6,
          );
      }
    },
  );
  return () => {
    media.revert();
    document.documentElement.classList.remove("has-motion");
  };
}
