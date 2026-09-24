import type { ResolvedConfig, CustomerAddress } from '../config/types';

export interface TestCustomer {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  salutationIndex: number;
  address: CustomerAddress;
}

const rand = () => Math.random().toString(36).slice(2, 8);

/** Unique e-mail per call: <prefix>.<timestamp>.<rand>@<domain> — easy to clean up by prefix. */
export function uniqueEmail(cfg: ResolvedConfig): string {
  const { emailPrefix, emailDomain } = cfg.testData.customer;
  return `${emailPrefix}.${Date.now()}.${rand()}@${emailDomain}`;
}

export function buildCustomer(cfg: ResolvedConfig, overrides: Partial<TestCustomer> = {}): TestCustomer {
  const c = cfg.testData.customer;
  return {
    email: uniqueEmail(cfg),
    password: c.password,
    firstName: c.firstName,
    lastName: c.lastName,
    salutationIndex: c.salutationIndex,
    address: { ...c.address },
    ...overrides,
  };
}
