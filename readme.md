# rate-limit-postgresql

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)

A [`PostgreSQL`](https://www.postgresql.org/) store for the [`express-rate-limit`](https://github.com/nfriedly/express-rate-limit) middleware.

## Installation

From the npm registry:

```sh
# Using npm
> npm install --save @acpr/rate-limit-postgresql
# Using yarn or pnpm
> yarn/pnpm add @acpr/rate-limit-postgresql
```

## Usage

```js
let rateLimit = require('express-rate-limit');
let postgresStores = require('@acpr/rate-limit-postgresql')

let limiter = new RateLimit({
  store: new postgresStores.PostgresStore(
    {
      user: 'postgres',
      password: 'postgres',
      host: 'localhost',
      database: 'rate-limit',
      port: 5432
    },
    'aggregated_store'
  ),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3, // Limit each IP to 3 requests per `window` (here, per 15 minutes)
  message:
    'Too many accounts created from this IP, please try again after 15 minutes',
  standardHeaders: 'draft-7', // Set `RateLimit` and `RateLimit-Policy`` headers
  legacyHeaders: false,
});

//  apply to all requests
app.use(limiter);
```


### Importing

This library is provided in ESM as well as CJS forms, and works with both Javascript and Typescript projects.

**This package requires you to use Node 14 or above.**

Import it in a CommonJS project (`type: commonjs` or no `type` field in `package.json`) as follows:

```ts
let postgresStores = require('@acpr/rate-limit-postgresql')
```

Import it in a ESM project (`type: module` in `package.json`) as follows:

```ts
import postgresStores from '@acpr/rate-limit-postgresql'
```


## Configuration

### Types of Postgres Stores
There are two different types of Postgres Stores:
1. `PostgresStoreAggregatedIP` (with the default `PostgresStore`)- which aggregates the IP count in the table, as shown in the following table 

| key         | session_id | count |
|-------------|------------|-------|
| 192.168.1.1 | 1          | 3     |
| 192.168.2.1 | 1          | 1     |


2. `PostgresStoreIndividualIP` - which stores the IP of each request in a separate row (as shown in the following table) and performs the aggregation at a separate step

| id | key         | session_id | event_time                |
|----|-------------|------------|---------------------------|
| 1  | 192.168.1.1 | 1          | 2023-09-13T07:40:09+00:00 |
| 2  | 192.168.1.1 | 1          | 2023-09-13T07:40:10+00:00 |
| 3  | 192.168.1.1 | 1          | 2023-09-13T07:40:11+00:00 |
| 4  | 192.168.2.1 | 1          | 2023-09-13T07:40:11+00:00 |

> Note: The database uses UUID as a data type for IDs, the tables contain integers as IDs to keep illustration simple.

### Constructor

Both types of store take the same input in their constructor 
- `config` - The database configuration as specified in the [node-postgres](https://node-postgres.com/apis/client) configuration.
- `name` - The unique name of the session. This is useful when applying multiple rate limiters with multiple stores.