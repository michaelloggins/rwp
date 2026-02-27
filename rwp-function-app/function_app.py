import json
import logging

import azure.functions as func

from config import get_settings
from models import RWPRequest
from synapse_client import SynapseClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

logger = logging.getLogger("rwp")


@app.route(route="results-with-pricing", methods=["GET"])
async def results_with_pricing(req: func.HttpRequest) -> func.HttpResponse:
    """HTTP trigger: query RWP or RWPCFO view by date range."""

    # Parse and validate parameters
    try:
        params = RWPRequest.from_request(req)
    except ValueError as e:
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=400,
            mimetype="application/json",
        )

    # Select view based on report type
    view_name = (
        "dbo.vw_ResultsWithPricingCFO"
        if params.report_type == "RWPCFO"
        else "dbo.vw_ResultsWithPricing"
    )

    query = f"""
        SELECT *
        FROM {view_name}
        WHERE DateEnter >= ?
          AND DateEnter <= ?
        ORDER BY CompName, Ordno
    """
    query_params = [params.cal_date.isoformat(), params.cal_end.isoformat()]

    settings = get_settings()
    client = SynapseClient(settings)

    try:
        rows, columns = await client.execute_query(query, query_params)
    except Exception:
        logger.exception("Failed to execute Synapse query")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error querying Synapse"}),
            status_code=500,
            mimetype="application/json",
        )

    # Return in requested format
    if params.output_format == "csv":
        return _build_csv_response(rows, columns)

    return _build_json_response(rows, columns)


def _build_json_response(
    rows: list[tuple], columns: list[str]
) -> func.HttpResponse:
    """Convert rows to JSON array of objects."""
    results = []
    for row in rows:
        record = {}
        for i, col in enumerate(columns):
            val = row[i]
            # Handle datetime serialization
            if hasattr(val, "isoformat"):
                val = val.isoformat()
            record[col] = val
        results.append(record)

    return func.HttpResponse(
        json.dumps(results, default=str),
        status_code=200,
        mimetype="application/json",
    )


def _build_csv_response(
    rows: list[tuple], columns: list[str]
) -> func.HttpResponse:
    """Convert rows to CSV with header row."""
    lines = [",".join(columns)]
    for row in rows:
        values = []
        for val in row:
            if val is None:
                values.append("")
            elif hasattr(val, "isoformat"):
                values.append(val.isoformat())
            else:
                s = str(val)
                if "," in s or '"' in s or "\n" in s:
                    s = '"' + s.replace('"', '""') + '"'
                values.append(s)
        lines.append(",".join(values))

    csv_content = "\n".join(lines)
    return func.HttpResponse(
        csv_content,
        status_code=200,
        mimetype="text/csv",
        headers={
            "Content-Disposition": "attachment; filename=results_with_pricing.csv"
        },
    )
