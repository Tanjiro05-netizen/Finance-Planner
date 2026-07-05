import { ApiError, notFound } from "../errors";
import type {
  CancellationMethod,
  CancellationRequestRecord,
  CancellationStatus,
  SiftRepositories
} from "../repositories/types";

export class CancellationService {
  constructor(
    private readonly repositories: SiftRepositories,
    private readonly options: { conciergeEnabled: boolean } = { conciergeEnabled: false }
  ) {}

  async create(input: {
    userId: string;
    subscriptionRef: string;
    merchantName: string;
    method: CancellationMethod;
  }): Promise<CancellationRequestRecord> {
    if (input.method === "concierge" && !this.options.conciergeEnabled) {
      throw new ApiError(
        403,
        "feature_disabled",
        "Concierge cancellation is coming soon. Guided cancellation is available now."
      );
    }

    return this.repositories.cancellations.create(input);
  }

  async list(userId: string): Promise<CancellationRequestRecord[]> {
    return this.repositories.cancellations.listByUser(userId);
  }

  async advance(input: {
    userId: string;
    id: string;
    status: Exclude<CancellationStatus, "requested">;
    note?: string;
  }): Promise<CancellationRequestRecord> {
    const request = await this.repositories.cancellations.advance(input);

    if (!request) {
      throw notFound("Cancellation request was not found.");
    }

    return request;
  }
}
