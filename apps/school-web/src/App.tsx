import { Layout } from "./components/Layout";
import { copyFor } from "./i18n";
import { About } from "./pages/About";
import { Contact } from "./pages/Contact";
import { Features } from "./pages/Features";
import { Home } from "./pages/Home";
import { NotFound } from "./pages/NotFound";
import { Schools } from "./pages/Schools";
import type { Lang, PageId } from "./routes";

/** One page of the public site. The same tree renders on the server and in the browser. */
export function App({ page, lang }: { page: PageId; lang: Lang }) {
  const copy = copyFor(lang);
  return (
    <Layout copy={copy} lang={lang} page={page}>
      {page === "home" && <Home copy={copy} lang={lang} />}
      {page === "features" && <Features copy={copy} lang={lang} />}
      {page === "schools" && <Schools copy={copy} />}
      {page === "about" && <About copy={copy} lang={lang} />}
      {page === "contact" && <Contact copy={copy} lang={lang} />}
      {page === "notFound" && <NotFound copy={copy} lang={lang} />}
    </Layout>
  );
}
