CREATE TYPE "PlaidItemStatus" AS ENUM ('active', 'needs_sync', 'error');
CREATE TYPE "CancellationMethod" AS ENUM ('concierge', 'guided');
CREATE TYPE "CancellationStatus" AS ENUM ('requested', 'contacting', 'confirmed', 'needsUser');

CREATE TABLE "User" (
  "id" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PlaidItem" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "accessTokenEnc" TEXT NOT NULL,
  "itemId" TEXT NOT NULL,
  "institutionName" TEXT NOT NULL,
  "cursor" TEXT,
  "status" "PlaidItemStatus" NOT NULL DEFAULT 'active',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PlaidItem_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Account" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "plaidItemId" TEXT NOT NULL,
  "plaidAccountId" TEXT NOT NULL,
  "mask" TEXT,
  "name" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  CONSTRAINT "Account_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Transaction" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "accountId" TEXT NOT NULL,
  "plaidTxnId" TEXT NOT NULL,
  "merchantName" TEXT NOT NULL,
  "amountMinor" INTEGER NOT NULL,
  "isoCurrency" TEXT NOT NULL,
  "date" TIMESTAMP(3) NOT NULL,
  "pending" BOOLEAN NOT NULL DEFAULT false,
  "category" TEXT,
  CONSTRAINT "Transaction_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "CancellationRequest" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "subscriptionRef" TEXT NOT NULL,
  "merchantName" TEXT NOT NULL,
  "method" "CancellationMethod" NOT NULL,
  "status" "CancellationStatus" NOT NULL DEFAULT 'requested',
  "note" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "CancellationRequest_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "PlaidItem_itemId_key" ON "PlaidItem"("itemId");
CREATE INDEX "PlaidItem_userId_idx" ON "PlaidItem"("userId");
CREATE UNIQUE INDEX "Account_plaidItemId_plaidAccountId_key" ON "Account"("plaidItemId", "plaidAccountId");
CREATE INDEX "Account_userId_idx" ON "Account"("userId");
CREATE UNIQUE INDEX "Transaction_plaidTxnId_key" ON "Transaction"("plaidTxnId");
CREATE INDEX "Transaction_userId_idx" ON "Transaction"("userId");
CREATE INDEX "Transaction_accountId_idx" ON "Transaction"("accountId");
CREATE INDEX "Transaction_date_idx" ON "Transaction"("date");
CREATE INDEX "CancellationRequest_userId_idx" ON "CancellationRequest"("userId");

ALTER TABLE "PlaidItem"
  ADD CONSTRAINT "PlaidItem_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Account"
  ADD CONSTRAINT "Account_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Account"
  ADD CONSTRAINT "Account_plaidItemId_fkey"
  FOREIGN KEY ("plaidItemId") REFERENCES "PlaidItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Transaction"
  ADD CONSTRAINT "Transaction_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Transaction"
  ADD CONSTRAINT "Transaction_accountId_fkey"
  FOREIGN KEY ("accountId") REFERENCES "Account"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CancellationRequest"
  ADD CONSTRAINT "CancellationRequest_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
