import { type BrowserContext, type Locator } from '@playwright/test';
import { BasePage } from '../pages/BasePage';

/** Shopware core cookie consent ("cookie-preference" cookie). */
export class CookieBanner extends BasePage {
  get banner(): Locator {
    return this.$(this.s.cookie.banner);
  }

  async acceptOnlyNecessary(): Promise<void> {
    await this.$(this.s.cookie.onlyNecessary).first().click();
  }

  async acceptAll(): Promise<void> {
    const all = this.$(this.s.cookie.acceptAll).first();
    if (await all.isVisible()) await all.click();
    else await this.acceptOnlyNecessary();
  }

  /**
   * Pre-sets consent so the banner never overlays elements in functional tests.
   * Used by the base fixture for every test (except the cookie banner test).
   */
  static async preAccept(context: BrowserContext, baseURL: string): Promise<void> {
    const { hostname } = new URL(baseURL);
    await context.addCookies([
      { name: 'cookie-preference', value: '1', domain: hostname, path: '/', sameSite: 'Lax' },
    ]);
  }
}
