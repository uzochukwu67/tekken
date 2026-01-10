import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Header } from "@/components/header"
import { Footer } from "@/components/footer"
import { Container } from "@/components/container"
import { Section } from "@/components/section"

export default function Home() {
  return (
    <div className="min-h-screen bg-white">
      <Header />

      {/* Hero Section */}
      <Section className="bg-gradient-to-br from-white via-white to-yellow-50">
        <Container>
          <div className="flex flex-col items-center text-center">
            <div className="mb-6 inline-block rounded-full border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary">
              Decentralized Sports Betting
            </div>

            <h1 className="mb-6 max-w-3xl text-4xl font-bold tracking-tight text-foreground md:text-5xl lg:text-6xl">
              Predict Premier League Matches with <span className="text-primary">Chainlink Randomness</span>
            </h1>

            <p className="mb-8 max-w-2xl text-lg text-muted-foreground md:text-xl">
              Place bets on Home Win, Draw, or Away Win predictions. Fair, transparent, and powered by smart contracts
              on the Sepolia testnet.
            </p>

            <div className="flex flex-col gap-4 sm:flex-row">
              <Link href="/betting">
                <Button className="h-12 bg-primary px-8 text-primary-foreground hover:bg-primary/90">
                  Start Betting Now
                </Button>
              </Link>
              <Button variant="outline" className="h-12 border-border px-8 bg-transparent" asChild>
                <a href="#how-it-works">Learn More</a>
              </Button>
            </div>

            {/* Hero Stats */}
            <div className="mt-16 grid gap-8 sm:grid-cols-3">
              <div className="rounded-lg border border-border bg-white p-6">
                <div className="text-3xl font-bold text-primary">380</div>
                <p className="mt-1 text-sm text-muted-foreground">Premier League Matches</p>
              </div>
              <div className="rounded-lg border border-border bg-white p-6">
                <div className="text-3xl font-bold text-primary">3</div>
                <p className="mt-1 text-sm text-muted-foreground">Bet Types per Match</p>
              </div>
              <div className="rounded-lg border border-border bg-white p-6">
                <div className="text-3xl font-bold text-primary">100%</div>
                <p className="mt-1 text-sm text-muted-foreground">Transparent & Fair</p>
              </div>
            </div>
          </div>
        </Container>
      </Section>

      {/* How It Works Section */}
      <Section id="how-it-works" className="border-t border-border bg-white">
        <Container>
          <div className="mb-12 text-center">
            <h2 className="mb-4 text-3xl font-bold text-foreground md:text-4xl">How It Works</h2>
            <p className="text-lg text-muted-foreground">Simple, transparent, and decentralized betting</p>
          </div>

          <div className="grid gap-8 md:grid-cols-4">
            {[
              {
                number: "1",
                title: "Connect Wallet",
                description: "Link your Web3 wallet to the platform on Sepolia testnet",
              },
              {
                number: "2",
                title: "Choose Match",
                description: "Select upcoming Premier League matches from the dashboard",
              },
              {
                number: "3",
                title: "Place Bet",
                description: "Predict Home Win, Draw, or Away Win with custom odds",
              },
              {
                number: "4",
                title: "Win & Settle",
                description: "Chainlink VRF determines results fairly and securely",
              },
            ].map((step) => (
              <div key={step.number} className="rounded-lg border border-border bg-white p-6 text-center">
                <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold mx-auto">
                  {step.number}
                </div>
                <h3 className="mb-2 font-semibold text-foreground">{step.title}</h3>
                <p className="text-sm text-muted-foreground">{step.description}</p>
              </div>
            ))}
          </div>
        </Container>
      </Section>

      {/* Features Section */}
      <Section className="border-t border-border bg-yellow-50/30">
        <Container>
          <div className="mb-12 text-center">
            <h2 className="mb-4 text-3xl font-bold text-foreground md:text-4xl">Why Choose ivisualz?</h2>
            <p className="text-lg text-muted-foreground">Built on trust, transparency, and smart contracts</p>
          </div>

          <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
            {[
              {
                title: "Chainlink VRF",
                description: "Verifiable random numbers ensure fair match outcomes",
              },
              {
                title: "Smart Contracts",
                description: "Automated settlement and transparent bet management",
              },
              {
                title: "Low Fees",
                description: "Minimal network fees with Sepolia testnet",
              },
              {
                title: "Real-Time Updates",
                description: "Live match odds and instant bet confirmation",
              },
              {
                title: "Secure Wallets",
                description: "Non-custodial betting with full control of your assets",
              },
              {
                title: "Detailed Analytics",
                description: "Track your betting history and performance metrics",
              },
            ].map((feature) => (
              <div key={feature.title} className="rounded-lg border border-border bg-white p-6">
                <div className="mb-3 h-2 w-12 rounded-full bg-primary"></div>
                <h3 className="mb-2 font-semibold text-foreground">{feature.title}</h3>
                <p className="text-sm text-muted-foreground">{feature.description}</p>
              </div>
            ))}
          </div>
        </Container>
      </Section>

      {/* CTA Section */}
      <Section className="border-t border-border bg-white">
        <Container>
          <div className="rounded-xl border border-primary/20 bg-gradient-to-r from-primary/5 to-white p-8 md:p-12 text-center">
            <h2 className="mb-4 text-3xl md:text-4xl font-bold text-foreground">Ready to Predict?</h2>
            <p className="mb-8 text-lg text-muted-foreground">
              Join the future of sports betting. Fair odds, instant settlement, complete transparency powered by
              Chainlink.
            </p>
            <Link href="/betting">
              <Button className="h-12 bg-primary px-8 text-primary-foreground hover:bg-primary/90 font-semibold">
                Start Betting Now
              </Button>
            </Link>
          </div>
        </Container>
      </Section>

      <Footer />
    </div>
  )
}
