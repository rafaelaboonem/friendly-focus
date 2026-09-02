import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, ChevronLeft, ChevronRight, Clock3, MapPin, Navigation, Search, ShieldCheck, Star, X } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";

export const Route = createFileRoute("/estacionar-agora")({
  validateSearch: (search: Record<string, unknown>) => ({
    destino: typeof search.destino === "string" ? search.destino : "",
    periodo: typeof search.periodo === "string" ? search.periodo : "",
  }),
  component: EstacionarAgora,
});

type Garage = {
  id: string;
  name: string;
  neighborhood: string;
  distance: string;
  rating: string;
  price: string;
  period: string;
  features: string[];
  image: string;
  position: { left: string; top: string };
};

const instantGarages: Garage[] = [
  {
    id: "pinheiros",
    name: "Garagem coberta em Pinheiros",
    neighborhood: "Pinheiros, São Paulo",
    distance: "a cerca de 450 m",
    rating: "4,9",
    price: "R$ 18",
    period: "por hora",
    features: ["Coberta", "Portão automático", "Câmera"],
    image: "https://images.unsplash.com/photo-1558008258-3256797b43f3?auto=format&fit=crop&w=900&q=80",
    position: { left: "30%", top: "31%" },
  },
  {
    id: "vila-madalena",
    name: "Vaga segura na Vila Madalena",
    neighborhood: "Vila Madalena, São Paulo",
    distance: "a cerca de 1,1 km",
    rating: "5,0",
    price: "R$ 20",
    period: "por hora",
    features: ["Coberta", "Iluminada", "Acesso fácil"],
    image: "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?auto=format&fit=crop&w=900&q=80",
    position: { left: "62%", top: "20%" },
  },
  {
    id: "sumare",
    name: "Garagem privativa no Sumaré",
    neighborhood: "Sumaré, São Paulo",
    distance: "a cerca de 1,6 km",
    rating: "4,8",
    price: "R$ 16",
    period: "por hora",
    features: ["Portão remoto", "Câmera", "Ampla entrada"],
    image: "https://images.unsplash.com/photo-1590674899484-d5640e854abe?auto=format&fit=crop&w=900&q=80",
    position: { left: "46%", top: "63%" },
  },
  {
    id: "perdizes",
    name: "Vaga coberta em Perdizes",
    neighborhood: "Perdizes, São Paulo",
    distance: "a cerca de 2,2 km",
    rating: "4,7",
    price: "R$ 17",
    period: "por hora",
    features: ["Coberta", "Porteiro", "Acesso 24h"],
    image: "https://images.unsplash.com/photo-1486325212027-8081e485255e?auto=format&fit=crop&w=900&q=80",
    position: { left: "76%", top: "56%" },
  },
];

function EstacionarAgora() {
  const { destino, periodo } = Route.useSearch();
  const [selectedId, setSelectedId] = useState(instantGarages[0].id);
  const selectedGarage = instantGarages.find((garage) => garage.id === selectedId) ?? instantGarages[0];
  const destinationLabel = destino || "Pinheiros, São Paulo";
  const periodLabel = periodo || "2 horas";

  function selectGarage(id: string) {
    setSelectedId(id);
  }

  function selectRelativeGarage(direction: number) {
    const currentIndex = instantGarages.findIndex((garage) => garage.id === selectedId);
    const nextIndex = (currentIndex + direction + instantGarages.length) % instantGarages.length;
    setSelectedId(instantGarages[nextIndex].id);
  }

  return (
    <main className="min-h-screen bg-background text-foreground lg:h-screen lg:overflow-hidden">
      <header className="relative z-20 border-b border-border bg-background px-4 py-3 sm:px-6">
        <div className="mx-auto flex max-w-[1600px] items-center gap-3">
          <Link to="/" className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-border bg-card transition-colors hover:bg-accent" aria-label="Voltar para a página inicial">
            <ArrowLeft className="size-4" aria-hidden="true" />
          </Link>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold">{destinationLabel}</p>
            <p className="truncate text-xs text-muted-foreground">Agora · {periodLabel}</p>
          </div>
          <Button variant="outline" className="h-10 shrink-0 rounded-xl px-3 sm:px-4" asChild>
            <Link to="/">Alterar busca</Link>
          </Button>
        </div>
        <div className="mx-auto mt-3 flex max-w-[1600px] items-center gap-2 text-xs text-muted-foreground lg:hidden">
          <ShieldCheck className="size-4 shrink-0" aria-hidden="true" />
          {instantGarages.length} garagens privadas disponíveis agora
        </div>
      </header>

      <div className="mx-auto max-w-[1600px] lg:grid lg:h-[calc(100vh-73px)] lg:grid-cols-[minmax(360px,0.82fr)_minmax(520px,1.18fr)]">
        <aside className="hidden overflow-y-auto border-r border-border bg-background lg:block">
          <div className="sticky top-0 z-10 border-b border-border bg-background px-6 py-5">
            <p className="text-sm text-muted-foreground">Disponíveis neste momento</p>
            <h1 className="mt-1 text-2xl font-semibold tracking-tight">{instantGarages.length} garagens privadas</h1>
            <p className="mt-2 flex items-center gap-2 text-xs text-muted-foreground">
              <ShieldCheck className="size-4" aria-hidden="true" />
              A localização é aproximada até a reserva ser confirmada.
            </p>
          </div>
          <div className="space-y-4 p-5">
            {instantGarages.map((garage) => (
              <GarageCard key={garage.id} garage={garage} selected={garage.id === selectedId} onSelect={() => selectGarage(garage.id)} />
            ))}
          </div>
        </aside>

        <section className="relative min-h-[calc(100vh-125px)] overflow-hidden bg-secondary lg:min-h-0" aria-label="Mapa de garagens disponíveis">
          <MapCanvas garages={instantGarages} selectedId={selectedId} onSelect={selectGarage} />

          <div className="absolute left-4 top-4 z-10 hidden rounded-full border border-border bg-background/95 px-3 py-2 text-xs font-medium shadow-sm backdrop-blur lg:flex lg:items-center lg:gap-2">
            <Search className="size-4" aria-hidden="true" />
            {instantGarages.length} disponíveis agora
          </div>

          <div className="absolute inset-x-0 bottom-0 z-10 p-3 sm:p-4 lg:hidden">
            <div className="mx-auto max-w-lg rounded-3xl border border-border bg-card p-3 shadow-xl shadow-foreground/15">
              <div className="mb-3 flex items-center justify-between gap-2 px-1">
                <p className="text-xs font-medium text-muted-foreground">{instantGarages.findIndex((garage) => garage.id === selectedId) + 1} de {instantGarages.length} disponíveis</p>
                <div className="flex gap-1">
                  <button type="button" onClick={() => selectRelativeGarage(-1)} className="flex size-9 items-center justify-center rounded-full border border-border bg-background" aria-label="Garagem anterior">
                    <ChevronLeft className="size-4" aria-hidden="true" />
                  </button>
                  <button type="button" onClick={() => selectRelativeGarage(1)} className="flex size-9 items-center justify-center rounded-full border border-border bg-background" aria-label="Próxima garagem">
                    <ChevronRight className="size-4" aria-hidden="true" />
                  </button>
                </div>
              </div>
              <GaragePreview garage={selectedGarage} />
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}

function MapCanvas({ garages, selectedId, onSelect }: { garages: Garage[]; selectedId: string; onSelect: (id: string) => void }) {
  return (
    <div className="absolute inset-0 overflow-hidden bg-secondary">
      <div className="absolute -left-[15%] top-[14%] h-[2px] w-[130%] rotate-[13deg] bg-border/70" />
      <div className="absolute -left-[10%] top-[47%] h-[3px] w-[125%] -rotate-[20deg] bg-border/80" />
      <div className="absolute left-[19%] top-[-12%] h-[125%] w-[2px] rotate-[25deg] bg-border/70" />
      <div className="absolute left-[56%] top-[-10%] h-[120%] w-[3px] -rotate-[32deg] bg-border/80" />
      <div className="absolute left-[12%] top-[24%] size-36 rounded-full border border-border/70 bg-background/25" />
      <div className="absolute bottom-[15%] right-[12%] size-44 rounded-full border border-border/70 bg-background/25" />
      <div className="absolute left-[7%] top-[10%] text-xs font-medium tracking-[0.18em] text-muted-foreground/70 uppercase">Vila Madalena</div>
      <div className="absolute right-[12%] top-[33%] text-xs font-medium tracking-[0.18em] text-muted-foreground/70 uppercase">Pinheiros</div>
      <div className="absolute bottom-[20%] left-[18%] text-xs font-medium tracking-[0.18em] text-muted-foreground/70 uppercase">Sumaré</div>
      <div className="absolute bottom-[9%] right-[18%] text-xs font-medium tracking-[0.18em] text-muted-foreground/70 uppercase">Perdizes</div>

      {garages.map((garage) => {
        const selected = garage.id === selectedId;
        return (
          <button
            key={garage.id}
            type="button"
            onClick={() => onSelect(garage.id)}
            className={selected ? "absolute z-10 -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary px-3 py-2 text-sm font-semibold text-primary-foreground shadow-lg ring-4 ring-primary/20 transition-transform hover:scale-105" : "absolute z-10 -translate-x-1/2 -translate-y-1/2 rounded-full border border-border bg-card px-3 py-2 text-sm font-semibold shadow-md transition-transform hover:scale-105"}
            style={garage.position}
            aria-label={`${garage.name}: ${garage.price}`}
          >
            {garage.price}
          </button>
        );
      })}

      <div className="absolute bottom-44 right-4 flex size-10 items-center justify-center rounded-xl border border-border bg-background/95 text-muted-foreground shadow-sm lg:bottom-4" aria-label="Localização aproximada">
        <Navigation className="size-4" aria-hidden="true" />
      </div>
    </div>
  );
}

function GarageCard({ garage, selected, onSelect }: { garage: Garage; selected: boolean; onSelect: () => void }) {
  return (
    <button
      type="button"
      onClick={onSelect}
      onMouseEnter={onSelect}
      className={selected ? "w-full overflow-hidden rounded-2xl border border-primary bg-card text-left shadow-md ring-1 ring-primary/20" : "w-full overflow-hidden rounded-2xl border border-border bg-card text-left shadow-sm transition-shadow hover:shadow-md"}
    >
      <img src={garage.image} alt="" className="h-40 w-full object-cover" />
      <div className="p-4">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-xs font-medium text-muted-foreground">Disponível agora</p>
            <h2 className="mt-1 truncate font-semibold">{garage.name}</h2>
            <p className="mt-1 flex items-center gap-1 text-sm text-muted-foreground"><MapPin className="size-3.5" aria-hidden="true" /> {garage.neighborhood}</p>
          </div>
          <span className="flex shrink-0 items-center gap-1 text-sm font-medium"><Star className="size-4 fill-current" aria-hidden="true" /> {garage.rating}</span>
        </div>
        <p className="mt-3 text-sm text-muted-foreground">{garage.features.join(" · ")}</p>
        <div className="mt-4 flex items-end justify-between gap-3">
          <p className="text-sm"><span className="font-semibold">{garage.price}</span> {garage.period}</p>
          <span className="text-xs text-muted-foreground">{garage.distance}</span>
        </div>
      </div>
    </button>
  );
}

function GaragePreview({ garage }: { garage: Garage }) {
  return (
    <div className="grid grid-cols-[108px_minmax(0,1fr)] gap-3">
      <img src={garage.image} alt={garage.name} className="h-32 w-full rounded-2xl object-cover" />
      <div className="min-w-0 py-1">
        <div className="flex items-center justify-between gap-2">
          <p className="text-xs font-medium text-muted-foreground">Disponível agora</p>
          <span className="flex shrink-0 items-center gap-1 text-xs font-medium"><Star className="size-3.5 fill-current" aria-hidden="true" /> {garage.rating}</span>
        </div>
        <h1 className="mt-1 truncate text-base font-semibold">{garage.name}</h1>
        <p className="mt-1 truncate text-sm text-muted-foreground">{garage.neighborhood} · {garage.distance}</p>
        <p className="mt-2 truncate text-xs text-muted-foreground">{garage.features.join(" · ")}</p>
        <div className="mt-3 flex items-center justify-between gap-2">
          <p className="text-sm"><span className="font-semibold">{garage.price}</span> {garage.period}</p>
          <Button size="sm" className="h-9 rounded-lg px-3">Ver garagem</Button>
        </div>
      </div>
    </div>
  );
}
