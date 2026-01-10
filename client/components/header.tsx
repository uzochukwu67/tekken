"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { ConnectButton } from "./connect-button"
import { cn } from "@/lib/utils"

const navLinks = [
  { href: "/", label: "Home" },
  { href: "/betting", label: "Bet Now" },
  { href: "/analytics", label: "Analytics" },
  { href: "/history", label: "History" },
]

export function Header() {
  const pathname = usePathname()

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-white">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary text-primary-foreground font-bold text-lg">
              IV
            </div>
            <span className="hidden font-bold text-foreground sm:inline">ivisualz</span>
          </Link>

          {/* Navigation */}
          <nav className="hidden gap-1 md:flex">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className={cn(
                  "px-3 py-2 text-sm font-medium rounded-md transition-colors",
                  pathname === link.href ? "bg-primary text-primary-foreground" : "text-foreground hover:bg-muted",
                )}
              >
                {link.label}
              </Link>
            ))}
          </nav>

          {/* Connect Button */}
          <div className="flex items-center gap-4">
            {/* <ConnectButton /> */}
          </div>
        </div>
      </div>
    </header>
  )
}
