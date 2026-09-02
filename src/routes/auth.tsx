import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { Car, Eye, EyeOff, LockKeyhole, Mail, UserRound } from "lucide-react";
import { useEffect, useState, type FormEvent } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/auth")({
  component: Auth,
});

type AuthMode = "login" | "signup";

type Feedback = {
  type: "error" | "success";
  message: string;
};

function Auth() {
  const navigate = useNavigate();
  const [mode, setMode] = useState<AuthMode>("login");
  const [showLoginPassword, setShowLoginPassword] = useState(false);
  const [showSignupPassword, setShowSignupPassword] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [feedback, setFeedback] = useState<Feedback | null>(null);

  useEffect(() => {
    const { data: subscription } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) {
        void navigate({ to: "/" });
      }
    });

    void supabase.auth.getSession().then(({ data }) => {
      if (data.session) {
        void navigate({ to: "/" });
      }
    });

    return () => subscription.subscription.unsubscribe();
  }, [navigate]);

  function changeMode(value: string) {
    setMode(value as AuthMode);
    setFeedback(null);
  }

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFeedback(null);

    const formData = new FormData(event.currentTarget);
    const email = String(formData.get("login-email") ?? "").trim();
    const password = String(formData.get("login-password") ?? "");

    if (!email || !password) {
      setFeedback({ type: "error", message: "Preencha seu e-mail e sua senha." });
      return;
    }

    setIsSubmitting(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setIsSubmitting(false);

    if (error) {
      setFeedback({ type: "error", message: translateAuthError(error.message) });
      return;
    }

    void navigate({ to: "/" });
  }

  async function handleSignup(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFeedback(null);

    const formData = new FormData(event.currentTarget);
    const fullName = String(formData.get("signup-name") ?? "").trim();
    const email = String(formData.get("signup-email") ?? "").trim();
    const password = String(formData.get("signup-password") ?? "");
    const confirmPassword = String(formData.get("signup-confirm-password") ?? "");

    if (!fullName || !email || !password || !confirmPassword) {
      setFeedback({ type: "error", message: "Preencha todos os campos para criar sua conta." });
      return;
    }

    if (!isValidEmail(email)) {
      setFeedback({ type: "error", message: "Informe um e-mail válido." });
      return;
    }

    if (password.length < 8) {
      setFeedback({ type: "error", message: "Sua senha precisa ter pelo menos 8 caracteres." });
      return;
    }

    if (password !== confirmPassword) {
      setFeedback({ type: "error", message: "A confirmação de senha não corresponde à senha informada." });
      return;
    }

    setIsSubmitting(true);
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/`,
        data: { full_name: fullName },
      },
    });
    setIsSubmitting(false);

    if (error) {
      setFeedback({ type: "error", message: translateAuthError(error.message) });
      return;
    }

    if (data.session) {
      void navigate({ to: "/" });
      return;
    }

    setFeedback({
      type: "success",
      message: "Conta criada. Confira seu e-mail para confirmar o cadastro antes de entrar.",
    });
  }

  return (
    <main className="min-h-screen bg-secondary/45 px-4 py-6 sm:px-6 sm:py-10">
      <div className="mx-auto flex min-h-[calc(100vh-3rem)] max-w-5xl items-center justify-center sm:min-h-[calc(100vh-5rem)]">
        <section className="grid w-full overflow-hidden rounded-3xl border border-border bg-card shadow-xl shadow-foreground/5 lg:grid-cols-[0.9fr_1.1fr]">
          <div className="hidden bg-primary p-10 text-primary-foreground lg:flex lg:flex-col lg:justify-between">
            <Link to="/" className="flex w-fit items-center gap-2 font-semibold tracking-tight">
              <span className="flex size-10 items-center justify-center rounded-xl bg-primary-foreground/15">
                <Car className="size-5" aria-hidden="true" />
              </span>
              <span className="text-lg">Vaga Privada</span>
            </Link>
            <div>
              <p className="text-sm font-semibold tracking-[0.16em] text-primary-foreground/70 uppercase">Garagens particulares</p>
              <h1 className="mt-4 text-4xl font-semibold tracking-tight">Sua vaga segura começa por aqui.</h1>
              <p className="mt-5 max-w-sm text-base leading-7 text-primary-foreground/80">
                Encontre e reserve vagas privadas para a sua rotina, ou anuncie uma garagem que está sem uso.
              </p>
            </div>
            <p className="text-sm text-primary-foreground/70">Uma única conta para estacionar e anunciar.</p>
          </div>

          <div className="p-6 sm:p-10">
            <div className="flex items-center justify-between gap-4 lg:hidden">
              <Link to="/" className="flex items-center gap-2 font-semibold tracking-tight">
                <span className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground">
                  <Car className="size-5" aria-hidden="true" />
                </span>
                <span className="text-lg">Vaga Privada</span>
              </Link>
              <Link to="/" className="text-sm font-medium underline underline-offset-4">Voltar</Link>
            </div>

            <div className="mt-10 lg:mt-0">
              <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">Acesse sua conta</h2>
              <p className="mt-2 text-sm leading-6 text-muted-foreground">Entre para continuar ou crie sua conta gratuitamente.</p>
            </div>

            <Tabs value={mode} onValueChange={changeMode} className="mt-7">
              <TabsList className="grid h-auto w-full grid-cols-2 rounded-xl p-1">
                <TabsTrigger value="login" className="min-h-11 rounded-lg">Entrar</TabsTrigger>
                <TabsTrigger value="signup" className="min-h-11 rounded-lg">Criar conta</TabsTrigger>
              </TabsList>

              <TabsContent value="login" className="mt-6">
                <form className="space-y-5" onSubmit={handleLogin} noValidate>
                  <AuthField id="login-email" name="login-email" label="E-mail" type="email" autoComplete="email" icon={<Mail />} placeholder="voce@exemplo.com" />
                  <PasswordField
                    id="login-password"
                    name="login-password"
                    label="Senha"
                    autoComplete="current-password"
                    visible={showLoginPassword}
                    onToggle={() => setShowLoginPassword((value) => !value)}
                  />
                  <div className="flex justify-end">
                    <button type="button" className="min-h-10 text-sm font-medium underline underline-offset-4">Esqueci minha senha</button>
                  </div>
                  <FeedbackMessage feedback={feedback} />
                  <Button type="submit" size="lg" className="h-12 w-full rounded-xl" disabled={isSubmitting}>
                    {isSubmitting ? "Entrando..." : "Entrar"}
                  </Button>
                </form>
              </TabsContent>

              <TabsContent value="signup" className="mt-6">
                <form className="space-y-5" onSubmit={handleSignup} noValidate>
                  <AuthField id="signup-name" name="signup-name" label="Nome" autoComplete="name" icon={<UserRound />} placeholder="Como podemos chamar você?" />
                  <AuthField id="signup-email" name="signup-email" label="E-mail" type="email" autoComplete="email" icon={<Mail />} placeholder="voce@exemplo.com" />
                  <PasswordField
                    id="signup-password"
                    name="signup-password"
                    label="Senha"
                    autoComplete="new-password"
                    visible={showSignupPassword}
                    onToggle={() => setShowSignupPassword((value) => !value)}
                    hint="Pelo menos 8 caracteres."
                  />
                  <PasswordField
                    id="signup-confirm-password"
                    name="signup-confirm-password"
                    label="Confirmar senha"
                    autoComplete="new-password"
                    visible={showSignupPassword}
                    onToggle={() => setShowSignupPassword((value) => !value)}
                  />
                  <FeedbackMessage feedback={feedback} />
                  <Button type="submit" size="lg" className="h-12 w-full rounded-xl" disabled={isSubmitting}>
                    {isSubmitting ? "Criando conta..." : "Criar conta"}
                  </Button>
                </form>
              </TabsContent>
            </Tabs>
          </div>
        </section>
      </div>
    </main>
  );
}

function AuthField({
  id,
  name,
  label,
  icon,
  type = "text",
  placeholder,
  autoComplete,
}: {
  id: string;
  name: string;
  label: string;
  icon: React.ReactNode;
  type?: React.HTMLInputTypeAttribute;
  placeholder: string;
  autoComplete: string;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <div className="relative">
        <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-muted-foreground">{icon}</span>
        <Input id={id} name={name} type={type} placeholder={placeholder} autoComplete={autoComplete} className="h-12 rounded-xl pl-10" />
      </div>
    </div>
  );
}

function PasswordField({
  id,
  name,
  label,
  autoComplete,
  visible,
  onToggle,
  hint,
}: {
  id: string;
  name: string;
  label: string;
  autoComplete: string;
  visible: boolean;
  onToggle: () => void;
  hint?: string;
}) {
  return (
    <div className="space-y-2">
      <div className="flex items-baseline justify-between gap-3">
        <Label htmlFor={id}>{label}</Label>
        {hint ? <span className="text-xs text-muted-foreground">{hint}</span> : null}
      </div>
      <div className="relative">
        <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-muted-foreground"><LockKeyhole className="size-4" /></span>
        <Input id={id} name={name} type={visible ? "text" : "password"} autoComplete={autoComplete} className="h-12 rounded-xl pl-10 pr-12" />
        <button
          type="button"
          onClick={onToggle}
          className="absolute inset-y-0 right-0 flex min-w-12 items-center justify-center rounded-r-xl text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
          aria-label={visible ? "Ocultar senha" : "Mostrar senha"}
        >
          {visible ? <EyeOff className="size-4" aria-hidden="true" /> : <Eye className="size-4" aria-hidden="true" />}
        </button>
      </div>
    </div>
  );
}

function FeedbackMessage({ feedback }: { feedback: Feedback | null }) {
  if (!feedback) return null;

  return (
    <p className={feedback.type === "error" ? "rounded-xl border border-destructive/30 bg-destructive/10 px-3 py-3 text-sm text-destructive" : "rounded-xl border border-border bg-secondary px-3 py-3 text-sm text-secondary-foreground"} role="status">
      {feedback.message}
    </p>
  );
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function translateAuthError(message: string) {
  const normalizedMessage = message.toLowerCase();

  if (normalizedMessage.includes("user already registered")) {
    return "Este e-mail já possui uma conta. Entre ou recupere sua senha.";
  }

  if (normalizedMessage.includes("invalid login credentials")) {
    return "E-mail ou senha incorretos. Tente novamente.";
  }

  if (normalizedMessage.includes("email not confirmed")) {
    return "Confirme seu e-mail antes de entrar na sua conta.";
  }

  if (normalizedMessage.includes("password should be at least")) {
    return "Sua senha precisa ter pelo menos 8 caracteres.";
  }

  if (normalizedMessage.includes("rate limit")) {
    return "Muitas tentativas em pouco tempo. Aguarde um instante e tente novamente.";
  }

  return "Não foi possível concluir agora. Verifique os dados e tente novamente.";
}
