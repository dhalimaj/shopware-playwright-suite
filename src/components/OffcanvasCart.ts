import { expect, type Locator } from '@playwright/test';
import { BasePage } from '../pages/BasePage';

export class OffcanvasCart extends BasePage {
  get root(): Locator {
    return this.$(this.s.offcanvasCart.root).first();
  }
  get lineItems(): Locator {
    return this.root.locator(this.s.offcanvasCart.lineItem);
  }

  lineItem(name: string): Locator {
    return this.lineItems.filter({ hasText: name }).first();
  }

  async expectOpen(): Promise<void> {
    await expect(this.root).toBeVisible();
  }

  async increaseQuantity(name: string): Promise<void> {
    await this.waitForXhr('/checkout/offcanvas', () => this.lineItem(name).locator(this.s.offcanvasCart.plus).click());
  }

  async remove(name: string): Promise<void> {
    await this.waitForXhr('/checkout/offcanvas', () => this.lineItem(name).locator(this.s.offcanvasCart.remove).click());
  }

  async goToCart(): Promise<void> {
    await Promise.all([this.page.waitForURL(/\/checkout\/cart/), this.root.locator(this.s.offcanvasCart.cartLink).first().click()]);
  }

  async goToCheckout(): Promise<void> {
    await Promise.all([
      this.page.waitForURL(/\/checkout\/(confirm|register)/),
      this.root.locator(this.s.offcanvasCart.checkoutButton).first().click(),
    ]);
  }

  async close(): Promise<void> {
    await this.root.locator(this.s.offcanvasCart.close).first().click();
    await expect(this.root).toBeHidden();
  }
}
