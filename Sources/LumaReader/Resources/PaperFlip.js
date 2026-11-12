// StPageFlip animates only disposable snapshots. Live content stays in LumaReader's reader.
async function playPaperFlip({ pages, columns, width, height, forward, milliseconds }) {
    const notify = message => window.webkit.messageHandlers.lumaPaperFlip.postMessage(message);
    try {
        await Promise.all(pages.map(async source => {
            const image = new Image();
            image.src = source;
            await image.decode();
        }));

        const flip = new St.PageFlip(document.getElementById("book"), {
            width: Math.max(1, width / columns),
            height,
            size: "fixed",
            startPage: forward ? 0 : columns,
            usePortrait: columns === 1,
            autoSize: false,
            useMouseEvents: false,
            showPageCorners: false,
            flippingTime: milliseconds,
            maxShadowOpacity: 0.45,
        });

        const destination = forward ? columns : 0;
        flip.on("init", () => {
            requestAnimationFrame(() => {
                notify("ready");
                requestAnimationFrame(() => {
                    if (forward) flip.flipNext("bottom");
                    else flip.flipPrev("bottom");
                });
            });
        });
        flip.on("flip", ({ data }) => {
            if (data === destination) requestAnimationFrame(() => notify("done"));
        });
        flip.loadFromImages(pages);
    } catch {
        notify("failed");
    }
}
