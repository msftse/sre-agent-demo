import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const products = [
  {
    id: 'field-pack-28',
    name: 'Field Pack 28',
    category: 'Carry',
    description: 'Weather-ready day pack.',
    price_cents: 14800,
    image_url: 'https://example.com/pack.jpg',
    image_alt: 'Olive technical backpack',
    accent: '#315c4c',
    badge: 'Field tested',
  },
]

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

describe('storefront', () => {
  beforeEach(() => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: RequestInfo | URL) => {
        const url = input.toString()
        if (url.endsWith('/api/products')) return jsonResponse(products)
        if (url.endsWith('/api/discounts/validate')) {
          return jsonResponse({
            code: 'WELCOME10',
            valid: true,
            discount_percent: 10,
            discount_cents: 1480,
            message: 'Welcome offer applied.',
          })
        }
        if (url.endsWith('/api/checkout')) {
          return jsonResponse({
            order_id: 'NS-TEST1234',
            status: 'confirmed',
            email: 'explorer@example.com',
            totals: {
              subtotal_cents: 14800,
              discount_cents: 0,
              shipping_cents: 1200,
              total_cents: 16000,
            },
            message: 'Order confirmed for explorer@example.com.',
          })
        }
        return jsonResponse({}, 404)
      }),
    )
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('loads the catalogue and adds a product to the bag', async () => {
    const user = userEvent.setup()
    render(<App />)

    expect(await screen.findByRole('heading', { name: 'Field Pack 28' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Add to bag' }))

    expect(screen.getByLabelText('1 items in bag')).toBeInTheDocument()
    expect(screen.getAllByText('$148.00').length).toBeGreaterThan(0)
    expect(screen.getByText('Build development')).toBeInTheDocument()
  })

  it('applies a server-validated discount', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(await screen.findByRole('button', { name: 'Add to bag' }))
    await user.type(screen.getByLabelText('Discount code'), 'welcome10')
    await user.click(screen.getByRole('button', { name: 'Apply' }))

    expect(await screen.findByText('Welcome offer applied.')).toBeInTheDocument()
    expect(screen.getByText('-$14.80')).toBeInTheDocument()
  })

  it('completes a healthy checkout', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(await screen.findByRole('button', { name: 'Add to bag' }))
    await user.type(screen.getByLabelText('Receipt email'), 'explorer@example.com')
    await user.click(screen.getByRole('button', { name: 'Place order' }))

    expect(await screen.findByText('Ready for the trail.')).toBeInTheDocument()
    expect(screen.getByText('NS-TEST1234')).toBeInTheDocument()
  })
})