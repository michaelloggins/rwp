import struct

from azure.identity.aio import DefaultAzureCredential

from config import Settings


class SynapseClient:
    """Executes queries against Synapse Serverless SQL Pool using managed identity."""

    # Synapse SQL endpoint scope for AAD token
    _SYNAPSE_SCOPE = "https://database.windows.net/.default"

    def __init__(self, settings: Settings):
        self._server = settings.synapse_endpoint
        self._database = settings.synapse_database

    async def execute_query(
        self, query: str, params: list[str] | None = None
    ) -> tuple[list[tuple], list[str]]:
        """Execute a SQL query and return (rows, column_names).

        Uses AAD managed identity for authentication -- no connection
        string secrets needed.
        """
        import aioodbc

        token = await self._get_access_token()
        conn_str = (
            f"Driver={{ODBC Driver 18 for SQL Server}};"
            f"Server={self._server};"
            f"Database={self._database};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=no;"
        )

        # Encode the AAD token for pyodbc/aioodbc
        token_bytes = self._encode_token(token)

        async with aioodbc.connect(
            dsn=conn_str,
            attrs_before={
                # SQL_COPT_SS_ACCESS_TOKEN = 1256
                1256: token_bytes
            },
        ) as conn:
            async with conn.cursor() as cursor:
                if params:
                    await cursor.execute(query, params)
                else:
                    await cursor.execute(query)

                columns = [desc[0] for desc in cursor.description]
                rows = await cursor.fetchall()

        return rows, columns

    async def _get_access_token(self) -> str:
        """Get an AAD access token for Synapse using managed identity."""
        async with DefaultAzureCredential() as credential:
            token = await credential.get_token(self._SYNAPSE_SCOPE)
            return token.token

    @staticmethod
    def _encode_token(token: str) -> bytes:
        """Encode AAD token as bytes for ODBC SQL_COPT_SS_ACCESS_TOKEN."""
        token_bytes = token.encode("utf-16-le")
        token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)
        return token_struct
