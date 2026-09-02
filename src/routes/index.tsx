import { createFileRoute } from "@tanstack/react-router";
import { Car, CalendarDays, Clock3, MapPin, Search, ShieldCheck, Star, WalletCards } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export const Route = createFileRoute("/")({
  component: Index,
});

const garages = [
  {
    name: "Garagem coberta em Pinheiros",
    neighborhood: "Pinheiros, São Paulo",
    features: "Coberta · Portão automático · Câmera",
    rating: "4,9",
    price: "R$ 18",
    period: "por hora",
    availability: "Disponível hoje",
    image: "https://images.unsplash.com/photo-1558008258-3256797b43f3?auto=format&fit=crop&w=900&q=80",
  },
  {
    name: "Vaga privativa perto da Paulista",
    neighborhood: "Bela Vista, São Paulo",
    features: "Acesso 24h · Iluminada · Fácil entrada",
    rating: "4,8",
    price: "R$ 22",
    period: "por hora",
    availability: "Última vaga para amanhã",
    image: "https://images.unsplash.com/photo-1590674899484-d5640e854abe?auto=format&fit=crop&w=900&q=80",
  },
  {
    name: "Garagem segura na Vila Madalena",
    neighborhood: "Vila Madalena, São Paulo",
    features: "Coberta · Manobrista · Câmera",
    rating: "5,0",
    price: "R$ 160",
    period: "por dia",
    availability: "Disponível este fim de semana",
    image: "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?auto=format&fit=crop&w=900&q=80",
  },
];

function Index() {
  const [searchMode, setSearchMode] = useState("schedule");

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-border bg-background/95">
        <div className="mx-auto flex min-h-18 max-w-7xl items-center justify-between gap-3 px-4 py-3 sm:px-6 lg:px-8">
          <a href="#inicio" className="flex items-center gap-2 font-semibold tracking-tight">
            <span className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground">
              <Car className="size-5" aria-hidden="true" />
            </span>
            <span className="text-lg">Vaga Privada</span>
          </a>

          <nav className="flex items-center gap-2">
            <Button variant="ghost" className="hidden sm:inline-flex" asChild>
              <a href="#anfitrioes">Anuncie sua garagem</a>
            </Button>
            <Button variant="outline" asChild>
              <a href="/auth">Entrar</a>
            </Button>
          </nav>
        </div>
      </header>

      <main id="inicio">
        <section className="mx-auto max-w-7xl px-4 pb-12 pt-12 sm:px-6 sm:pt-18 lg:px-8 lg:pb-20">
          <div className="mx-auto max-w-3xl text-center">
            <p className="text-sm font-semibold tracking-[0.16em] text-muted-foreground uppercase">Garagens particulares, perto de você</p>
            <h1 className="mt-4 text-4xl font-semibold tracking-tight sm:text-5xl lg:text-6xl">
              Estacione com mais tranquilidade.
            </h1>
            <p className="mx-auto mt-5 max-w-2xl text-base leading-7 text-muted-foreground sm:text-lg">
              Reserve uma vaga em garagens privadas, com praticidade para sua rotina e mais segurança para o seu carro.
            </p>
          </div>

          <div className="mx-auto mt-9 max-w-5xl rounded-3xl border border-border bg-card p-3 shadow-lg shadow-foreground/5 sm:p-5">
            <Tabs value={searchMode} onValueChange={setSearchMode}>
              <TabsList className="grid h-auto w-full grid-cols-2 rounded-2xl p-1 sm:mx-auto sm:w-auto">
                <TabsTrigger value="schedule" className="min-h-11 rounded-xl px-4">Agendar</TabsTrigger>
                <TabsTrigger value="now" className="min-h-11 rounded-xl px-4">Estacionar agora</TabsTrigger>
              </TabsList>

              <TabsContent value="schedule" className="mt-5">
                <form className="grid gap-3 lg:grid-cols-[1.45fr_0.9fr_0.9fr_auto] lg:items-end" onSubmit={(event) => event.preventDefault()}>
                  <SearchField label="Onde você quer estacionar?" icon={<MapPin />} placeholder="Bairro, endereço ou ponto de referência" />
                  <SearchField label="Entrada" icon={<CalendarDays />} type="date" />
                  <SearchField label="Horário" icon={<Clock3 />} type="time" />
                  <SearchField label="Saída" icon={<CalendarDays />} type="datetime-local" />
                  <Button type="submit" size="lg" className="h-12 w-full rounded-xl lg:w-auto">
                    <Search aria-hidden="true" /> Buscar
                  </Button>
                </form>
              </TabsContent>

              <TabsContent value="now" className="mt-5">
                <form className="grid gap-3 lg:grid-cols-[1.45fr_1fr_auto] lg:items-end" onSubmit={(event) => event.preventDefault()}>
                  <SearchField label="Qual é seu destino?" icon={<MapPin />} placeholder="Bairro, endereço ou ponto de referência" />
                  <SearchField label="Por quanto tempo?" icon={<Clock3 />} placeholder="Ex.: 2 horas" />
                  <Button type="submit" size="lg" className="h-12 w-full rounded-xl lg:w-auto">
                    <Search aria-hidden="true" /> Encontrar garagem agora
                  </Button>
                </form>
              </TabsContent>
            </Tabs>
            <p className="mt-4 flex items-center justify-center gap-2 text-center text-xs text-muted-foreground">
              <ShieldCheck className="size-4 shrink-0" aria-hidden="true" />
              Apenas vagas em garagens privadas — não são vagas de rua.
            </p>
          </div>
        </section>

        <section className="border-y border-border bg-secondary/45 py-12 sm:py-16">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p className="text-sm font-semibold text-muted-foreground">Perto de você</p>
                <h2 className="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">Garagens recomendadas</h2>
              </div>
              <a href="#garagens" className="text-sm font-medium underline underline-offset-4">Ver todas as garagens</a>
            </div>

            <div id="garagens" className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {garages.map((garage) => (
                <article key={garage.name} className="overflow-hidden rounded-2xl border border-border bg-card shadow-sm transition-transform hover:-translate-y-1">
                  <img src={garage.image} alt={garage.name} className="h-52 w-full object-cover" />
                  <div className="p-5">
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <h3 className="truncate font-semibold">{garage.name}</h3>
                        <p className="mt-1 text-sm text-muted-foreground">{garage.neighborhood}</p>
                      </div>
                      <span className="flex shrink-0 items-center gap-1 text-sm font-medium"><Star className="size-4 fill-current" aria-hidden="true" /> {garage.rating}</span>
                    </div>
                    <p className="mt-4 text-sm text-muted-foreground">{garage.features}</p>
                    <div className="mt-5 flex items-end justify-between gap-3">
                      <p className="text-sm"><span className="font-semibold">{garage.price}</span> {garage.period}</p>
                      <span className="text-right text-xs font-medium text-muted-foreground">{garage.availability}</span>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section id="anfitrioes" className="mx-auto max-w-7xl px-4 py-14 sm:px-6 sm:py-20 lg:px-8">
          <div className="grid items-center gap-8 rounded-3xl bg-primary px-6 py-10 text-primary-foreground sm:px-10 lg:grid-cols-[1fr_auto] lg:px-14 lg:py-14">
            <div className="max-w-2xl">
              <div className="flex size-11 items-center justify-center rounded-xl bg-primary-foreground/15"><WalletCards className="size-5" aria-hidden="true" /></div>
              <h2 className="mt-5 text-3xl font-semibold tracking-tight sm:text-4xl">Sua vaga livre pode render para você.</h2>
              <p className="mt-4 text-base leading-7 text-primary-foreground/80 sm:text-lg">
                Transforme uma garagem privada sem uso em uma renda extra. Você escolhe quando disponibilizar sua vaga e mantém o controle da sua rotina.
              </p>
            </div>
            <Button variant="secondary" size="lg" className="h-12 rounded-xl" asChild>
              <a href="/auth">Anuncie sua garagem</a>
            </Button>
          </div>
        </section>
      </main>

      <footer className="border-t border-border py-7">
        <div className="mx-auto flex max-w-7xl flex-col gap-2 px-4 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
          <p>© 2026 Vaga Privada</p>
          <p>Vagas em garagens particulares.</p>
        </div>
      </footer>
    </div>
  );
}

function SearchField({
  label,
  icon,
  placeholder,
  type = "text",
}: {
  label: string;
  icon: React.ReactNode;
  placeholder?: string;
  type?: React.HTMLInputTypeAttribute;
}) {
  const fieldId = label.toLowerCase().replaceAll(" ", "-").replaceAll("?", "");

  return (
    <div className="rounded-xl border border-border bg-background px-3 py-2 transition-colors focus-within:border-ring">
      <Label htmlFor={fieldId} className="flex items-center gap-2 text-xs text-muted-foreground">
        {icon}
        {label}
      </Label>
      <Input id={fieldId} type={type} placeholder={placeholder} className="mt-1 h-6 border-0 px-0 text-sm shadow-none focus-visible:ring-0" />
    </div>
  );
}
