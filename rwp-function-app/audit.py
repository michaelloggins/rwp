import logging
import os
import uuid
from datetime import datetime, timezone

from azure.data.tables import TableClient

logger = logging.getLogger("rwp.audit")

_TABLE_NAME = "AuditLog"
_table_client: TableClient | None = None
_table_ensured = False


def _get_table_client() -> TableClient:
    """Return a cached TableClient, creating the table if needed."""
    global _table_client, _table_ensured

    if _table_client is None:
        conn_str = os.environ.get("AzureWebJobsStorage", "")
        if not conn_str:
            raise RuntimeError("AzureWebJobsStorage not configured")
        _table_client = TableClient.from_connection_string(conn_str, _TABLE_NAME)

    if not _table_ensured:
        _table_client.create_table()
        _table_ensured = True

    return _table_client


def log_action(
    user: str,
    year: int,
    month: int,
    action: str,
    version: str,
    filename: str,
    row_count: int,
    status: str,
) -> None:
    """Write an audit record to Azure Table Storage.

    Fire-and-forget: errors are logged but never propagate to the caller.
    """
    try:
        now = datetime.now(timezone.utc)
        # Reverse-tick timestamp: newest records sort first in partition scans
        reverse_ticks = str(2**63 - int(now.timestamp() * 1e7))
        short_id = uuid.uuid4().hex[:8]

        entity = {
            "PartitionKey": now.strftime("%Y-%m"),
            "RowKey": f"{reverse_ticks}_{short_id}",
            "User": user,
            "Timestamp_UTC": now.isoformat(),
            "ReportYear": year,
            "ReportMonth": month,
            "Action": action,
            "Version": version,
            "FileName": filename,
            "RowCount": row_count,
            "Status": status,
        }

        client = _get_table_client()
        client.create_entity(entity)
    except Exception:
        logger.exception("Failed to write audit log entry")


def query_log(partition_key: str) -> list[dict]:
    """Query audit log entries for a given YYYY-MM partition.

    Returns a list of entity dicts sorted newest-first (by RowKey).
    """
    client = _get_table_client()
    entities = client.query_entities(
        query_filter="PartitionKey eq @pk",
        parameters={"pk": partition_key},
        select=[
            "RowKey", "User", "Timestamp_UTC", "ReportYear", "ReportMonth",
            "Action", "Version", "FileName", "RowCount", "Status",
        ],
    )
    return [dict(e) for e in entities]
