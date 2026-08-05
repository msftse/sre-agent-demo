import { useEffect, useState, type CSSProperties, type FormEvent } from 'react'
import {
  AlertCircle,
  ArrowRight,
  Check,
  Compass,
  LoaderCircle,
  Minus,
  PackageCheck,
  Plus,
  ShieldCheck,
  ShoppingBag,
  Tag,
} from 'lucide-react'
import { checkout, getProducts, validateDiscount } from './api'
import type { CheckoutResponse, DiscountQuote, Product } from './types'
import './App.css'

const formatCurrency = (cents: number) =>
  new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(cents / 100)

const frontendBuildSha = import.meta.env.VITE_GIT_SHA ?? 'development'

function App() {
  const [products, setProducts] = useState<Product[]>([])
  const [cart, setCart] = useState<Record<string, number>>({})
  const [catalogueError, setCatalogueError] = useState('')
  const [isLoading, setIsLoading] = useState(true)
  const [discountCode, setDiscountCode] = useState('')
  const [discount, setDiscount] = useState<DiscountQuote | null>(null)
  const [discountError, setDiscountError] = useState('')
  const [email, setEmail] = useState('')
  const [checkoutError, setCheckoutError] = useState('')
  const [isCheckingOut, setIsCheckingOut] = useState(false)
  const [order, setOrder] = useState<CheckoutResponse | null>(null)

  useEffect(() => {
    let isCurrent = true

    getProducts()
      .then((catalogue) => {
        if (isCurrent) setProducts(catalogue)
      })
      .catch((error: unknown) => {
        if (isCurrent) {
          setCatalogueError(
            error instanceof Error ? error.message : 'The catalogue is unavailable.',
          )
        }
      })
      .finally(() => {
        if (isCurrent) setIsLoading(false)
      })

    return () => {
      isCurrent = false
    }
  }, [])

  const cartLines = products
    .filter((product) => cart[product.id])
    .map((product) => ({ product, quantity: cart[product.id] }))
  const cartCount = cartLines.reduce((total, line) => total + line.quantity, 0)
  const subtotal = cartLines.reduce(
    (total, line) => total + line.product.price_cents * line.quantity,
    0,
  )
  const estimatedShipping = subtotal >= 15000 || subtotal === 0 ? 0 : 1200
  const estimatedTotal =
    subtotal - (discount?.valid ? discount.discount_cents : 0) + estimatedShipping

  const adjustQuantity = (productId: string, change: number) => {
    setCart((current) => {
      const quantity = Math.min(10, Math.max(0, (current[productId] ?? 0) + change))
      const next = { ...current }
      if (quantity === 0) delete next[productId]
      else next[productId] = quantity
      return next
    })
    setDiscount(null)
    setDiscountError('')
    setOrder(null)
  }

  const applyDiscount = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setDiscountError('')
    if (!discountCode.trim()) {
      setDiscountError('Enter a discount code first.')
      return
    }
    if (subtotal === 0) {
      setDiscountError('Add an item before applying a discount.')
      return
    }

    try {
      const quote = await validateDiscount(discountCode, subtotal)
      setDiscount(quote)
      setDiscountCode(quote.code)
    } catch (error) {
      setDiscountError(error instanceof Error ? error.message : 'Could not check that code.')
    }
  }

  const placeOrder = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setCheckoutError('')
    setIsCheckingOut(true)

    try {
      const confirmation = await checkout({
        email,
        items: cartLines.map((line) => ({
          product_id: line.product.id,
          quantity: line.quantity,
        })),
        discount_code: discount?.valid ? discount.code : undefined,
      })
      setOrder(confirmation)
      setCart({})
      setDiscount(null)
      setDiscountCode('')
    } catch (error) {
      setCheckoutError(error instanceof Error ? error.message : 'Checkout could not be completed.')
    } finally {
      setIsCheckingOut(false)
    }
  }

  return (
    <div className="app-shell">
      <header className="site-header">
        <a className="brand" href="#catalogue" aria-label="Northstar Supply home">
          <span className="brand-mark" aria-hidden="true">
            <Compass size={21} strokeWidth={2.2} />
          </span>
          <span>Northstar Supply</span>
        </a>
        <div className="header-actions">
          <span className="shipping-note">Free shipping over $150</span>
          <a className="cart-link" href="#order-summary">
            <ShoppingBag size={18} aria-hidden="true" />
            <span>Bag</span>
            <span className="cart-count" aria-label={`${cartCount} items in bag`}>
              {cartCount}
            </span>
          </a>
        </div>
      </header>

      <main>
        <section className="intro-band" aria-labelledby="page-title">
          <div className="intro-copy">
            <p className="eyebrow">Field notes / Issue 04</p>
            <h1 id="page-title">Equipment for the long way round.</h1>
            <p className="intro-text">
              A compact collection of dependable trail goods, selected for repairability,
              weather resistance, and years of useful miles.
            </p>
          </div>
          <div className="field-note" aria-label="Collection details">
            <span>04 pieces</span>
            <span>Tested above 2,000 m</span>
            <span>Ships in 1-2 days</span>
          </div>
        </section>

        <div className="store-layout">
          <section id="catalogue" className="catalogue" aria-labelledby="catalogue-title">
            <div className="section-heading">
              <div>
                <p className="eyebrow">The field collection</p>
                <h2 id="catalogue-title">Built to leave the road</h2>
              </div>
              <p>{products.length || 'Four'} purpose-built essentials</p>
            </div>

            {isLoading && (
              <div className="catalogue-state" role="status">
                <LoaderCircle className="spin" size={22} aria-hidden="true" />
                Loading the field collection...
              </div>
            )}

            {catalogueError && (
              <div className="catalogue-state error-state" role="alert">
                <AlertCircle size={22} aria-hidden="true" />
                <div>
                  <strong>Catalogue unavailable</strong>
                  <span>{catalogueError}</span>
                </div>
              </div>
            )}

            {!isLoading && !catalogueError && (
              <div className="product-grid">
                {products.map((product, index) => {
                  const quantity = cart[product.id] ?? 0
                  return (
                    <article
                      className="product-card"
                      key={product.id}
                      style={
                        {
                          '--product-accent': product.accent,
                          '--index': index,
                        } as CSSProperties
                      }
                    >
                      <div className="product-image-wrap">
                        <img src={product.image_url} alt={product.image_alt} loading="lazy" />
                        <span className="product-index">0{index + 1}</span>
                        {product.badge && <span className="product-badge">{product.badge}</span>}
                      </div>
                      <div className="product-content">
                        <div className="product-meta">
                          <span>{product.category}</span>
                          <strong>{formatCurrency(product.price_cents)}</strong>
                        </div>
                        <h3>{product.name}</h3>
                        <p>{product.description}</p>
                        {quantity === 0 ? (
                          <button
                            className="add-button"
                            type="button"
                            onClick={() => adjustQuantity(product.id, 1)}
                          >
                            Add to bag
                            <Plus size={17} aria-hidden="true" />
                          </button>
                        ) : (
                          <div className="quantity-control" aria-label={`${product.name} quantity`}>
                            <button
                              type="button"
                              onClick={() => adjustQuantity(product.id, -1)}
                              aria-label={`Remove one ${product.name}`}
                              title="Remove one"
                            >
                              <Minus size={16} aria-hidden="true" />
                            </button>
                            <span aria-live="polite">{quantity}</span>
                            <button
                              type="button"
                              onClick={() => adjustQuantity(product.id, 1)}
                              aria-label={`Add one ${product.name}`}
                              title="Add one"
                              disabled={quantity >= 10}
                            >
                              <Plus size={16} aria-hidden="true" />
                            </button>
                          </div>
                        )}
                      </div>
                    </article>
                  )
                })}
              </div>
            )}
          </section>

          <aside id="order-summary" className="order-panel" aria-labelledby="order-title">
            {order ? (
              <div className="confirmation" role="status">
                <span className="confirmation-icon" aria-hidden="true">
                  <PackageCheck size={25} />
                </span>
                <p className="eyebrow">Order confirmed</p>
                <h2>Ready for the trail.</h2>
                <p>{order.message}</p>
                <dl>
                  <div>
                    <dt>Order</dt>
                    <dd>{order.order_id}</dd>
                  </div>
                  <div>
                    <dt>Total</dt>
                    <dd>{formatCurrency(order.totals.total_cents)}</dd>
                  </div>
                </dl>
                <button className="secondary-button" type="button" onClick={() => setOrder(null)}>
                  Continue shopping
                </button>
              </div>
            ) : (
              <>
                <div className="order-heading">
                  <div>
                    <p className="eyebrow">Your bag</p>
                    <h2 id="order-title">Order summary</h2>
                  </div>
                  <span>{cartCount} items</span>
                </div>

                {cartLines.length === 0 ? (
                  <div className="empty-cart">
                    <ShoppingBag size={24} aria-hidden="true" />
                    <p>Your bag is ready for its first piece.</p>
                    <a href="#catalogue">Browse the collection</a>
                  </div>
                ) : (
                  <ul className="cart-lines">
                    {cartLines.map((line) => (
                      <li key={line.product.id}>
                        <div>
                          <strong>{line.product.name}</strong>
                          <span>Qty {line.quantity}</span>
                        </div>
                        <span>{formatCurrency(line.product.price_cents * line.quantity)}</span>
                      </li>
                    ))}
                  </ul>
                )}

                <form className="discount-form" onSubmit={applyDiscount}>
                  <label htmlFor="discount-code">Discount code</label>
                  <div className="field-row">
                    <div className="input-wrap">
                      <Tag size={16} aria-hidden="true" />
                      <input
                        id="discount-code"
                        value={discountCode}
                        onChange={(event) => setDiscountCode(event.target.value)}
                        placeholder="WELCOME10"
                        autoComplete="off"
                      />
                    </div>
                    <button className="secondary-button" type="submit">
                      Apply
                    </button>
                  </div>
                  {discountError && (
                    <p className="field-message error-message" role="alert">
                      {discountError}
                    </p>
                  )}
                  {discount && (
                    <p
                      className={`field-message ${
                        discount.valid ? 'success-message' : 'error-message'
                      }`}
                    >
                      {discount.valid && <Check size={15} aria-hidden="true" />}
                      {discount.message}
                    </p>
                  )}
                </form>

                <dl className="totals">
                  <div>
                    <dt>Subtotal</dt>
                    <dd>{formatCurrency(subtotal)}</dd>
                  </div>
                  {discount?.valid && (
                    <div className="discount-line">
                      <dt>Discount</dt>
                      <dd>-{formatCurrency(discount.discount_cents)}</dd>
                    </div>
                  )}
                  <div>
                    <dt>Shipping</dt>
                    <dd>{estimatedShipping === 0 ? 'Free' : formatCurrency(estimatedShipping)}</dd>
                  </div>
                  <div className="total-line">
                    <dt>Total</dt>
                    <dd>{formatCurrency(estimatedTotal)}</dd>
                  </div>
                </dl>

                <form className="checkout-form" onSubmit={placeOrder}>
                  <label htmlFor="email">Receipt email</label>
                  <input
                    id="email"
                    type="email"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    placeholder="explorer@example.com"
                    required
                  />
                  {checkoutError && (
                    <p className="field-message error-message" role="alert">
                      {checkoutError}
                    </p>
                  )}
                  <button
                    className="checkout-button"
                    type="submit"
                    disabled={cartLines.length === 0 || isCheckingOut}
                  >
                    {isCheckingOut ? (
                      <>
                        <LoaderCircle className="spin" size={18} aria-hidden="true" />
                        Placing order
                      </>
                    ) : (
                      <>
                        Place order
                        <ArrowRight size={18} aria-hidden="true" />
                      </>
                    )}
                  </button>
                  <p className="secure-note">
                    <ShieldCheck size={15} aria-hidden="true" />
                    Demo checkout. No payment or personal data is stored.
                  </p>
                </form>
              </>
            )}
          </aside>
        </div>
      </main>

      <footer>
        <span>Northstar Supply Co.</span>
        <span>Build {frontendBuildSha.slice(0, 12)}</span>
      </footer>
    </div>
  )
}

export default App