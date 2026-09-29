---
name: Creative Backgrounds
colors:
  surface: '#fbf9f9'
  surface-dim: '#dbdad9'
  surface-bright: '#fbf9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f3'
  surface-container: '#efeded'
  surface-container-high: '#e9e8e7'
  surface-container-highest: '#e3e2e2'
  on-surface: '#1b1c1c'
  on-surface-variant: '#444748'
  inverse-surface: '#303031'
  inverse-on-surface: '#f2f0f0'
  outline: '#747878'
  outline-variant: '#c4c7c7'
  surface-tint: '#5f5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1c1b1b'
  on-primary-container: '#858383'
  inverse-primary: '#c8c6c5'
  secondary: '#5d5f5f'
  on-secondary: '#ffffff'
  secondary-container: '#dcdddd'
  on-secondary-container: '#5f6161'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1c1b1a'
  on-tertiary-container: '#868382'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e5e2e1'
  primary-fixed-dim: '#c8c6c5'
  on-primary-fixed: '#1c1b1b'
  on-primary-fixed-variant: '#474746'
  secondary-fixed: '#e2e2e2'
  secondary-fixed-dim: '#c6c6c7'
  on-secondary-fixed: '#1a1c1c'
  on-secondary-fixed-variant: '#454747'
  tertiary-fixed: '#e6e2df'
  tertiary-fixed-dim: '#cac6c4'
  on-tertiary-fixed: '#1c1b1a'
  on-tertiary-fixed-variant: '#484645'
  background: '#fbf9f9'
  on-background: '#1b1c1c'
  surface-variant: '#e3e2e2'
typography:
  display:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-page: 24px
  gutter-grid: 16px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
  stack-xl: 64px
---

## Brand & Style

The design system is centered on a **Premium Minimalism** aesthetic that prioritizes the wallpaper content as the primary source of color and emotion. It is designed to evoke a sense of digital luxury, calm, and intentionality.

The style is a fusion of **Glassmorphism** and **Corporate Modernism**. It utilizes high-transparency frosted surfaces, expansive whitespace, and a strict adherence to a monochromatic UI palette. The interface acts as a "museum gallery" frame—sophisticated, quiet, and high-end—allowing the high-resolution imagery to take center stage. Drawing inspiration from Apple and Linear, the interaction model feels weightless, using subtle depth and large radii to create a friendly yet professional atmosphere.

## Colors

The palette is strictly achromatic to ensure no UI element competes with the wallpapers. 

- **Primary:** Soft Black (#1A1A1A) is used for high-impact typography and primary call-to-action buttons.
- **Secondary/Surface:** Light Gray (#F2F2F2) and semi-transparent whites are used for container backgrounds and secondary actions.
- **Neutral:** Mid-Grays are reserved for secondary labels, metadata, and placeholder states.
- **Glass:** A custom variable for glass backgrounds should utilize a 40-70% opacity white with a 20px - 40px backdrop blur.

The "accent" of the app is dynamic—it is derived entirely from the vibrant colors found in the featured wallpapers.

## Typography

The system uses **Inter** exclusively to achieve a modern, systematic feel. 

Hierarchy is established through extreme contrast in weight and size. Display and Large Headlines use heavy weights and tight letter-spacing for a bold, editorial look. Body text remains airy with generous line heights to maintain readability against varied backgrounds. Labels are kept minimal, often using uppercase or medium weights to differentiate them from body copy without increasing visual noise.

## Layout & Spacing

This design system follows a **Fluid Grid** model optimized for mobile-first interaction (Flutter). 

- **Margins:** A standard 24px horizontal margin ensures the UI feels spacious and "premium," preventing content from feeling cramped against screen edges.
- **Grids:** Wallpaper thumbnails should utilize a 2-column masonry or fixed-aspect-ratio grid with 16px gutters.
- **Rhythm:** Spacing follows an 8px base unit. Large gaps (32px+) are encouraged between logical sections to emphasize the minimal aesthetic.
- **Safe Areas:** Floating components (like navigation bars) must maintain a 16px distance from the bottom safe area to enhance the "floating" effect.

## Elevation & Depth

Depth is conveyed through **Glassmorphism** and **Ambient Shadows** rather than traditional opaque stacking.

1.  **Floating Glass:** Primary UI overlays (search bars, bottom sheets, navigation) use a semi-transparent white background with a heavy backdrop blur (Blur: 30px). A thin, 0.5px white border (30% opacity) should be added to define the edges of these glass elements.
2.  **Soft Shadows:** Use very diffused, low-opacity shadows (Color: #000000, Opacity: 4-6%, Blur: 40px) to give components a sense of lifting off the wallpaper.
3.  **Tonal Depth:** For non-glass elements, depth is created by placing white cards (#FFFFFF) on light gray backgrounds (#F2F2F2).

## Shapes

The shape language is defined by **Large Rounded Corners**, creating an organic and soft feel.

- **Cards & Containers:** Use a primary radius of 32px for large wallpaper cards and main containers.
- **Secondary Elements:** Smaller components like input fields or smaller cards use a 16px radius.
- **Interactive Elements:** Buttons and chips use a "Pill" shape (100px radius) to maximize the "squishy" and tactile feeling associated with high-end mobile apps.

## Components

- **Buttons:** Primary buttons are Solid Soft Black (#1A1A1A) with White text. Secondary buttons are Glass-based (Frosted White) with Black text. All buttons use the Pill-shape.
- **Input Fields:** Search bars should be floating glass elements with a 16px radius, featuring a subtle "Search" icon and minimal placeholder text.
- **Cards:** Wallpaper cards are the hero. They use a 32px radius and no border. Details (title, artist) should appear on a glass gradient overlay at the bottom of the card only when relevant.
- **Chips:** Used for categories. These are small, pill-shaped, and use a light gray (#F2F2F2) background for inactive states and Solid Black for active.
- **Navigation:** A floating bottom bar using the Glassmorphic style. Icons should be thin-stroke (1.5pt) to match the Inter font weight.
- **Dividers:** Extremely subtle. 1px width, #000000 with 5-8% opacity.