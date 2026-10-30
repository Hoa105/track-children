FROM rocker/r-ver:4.6.1@sha256:bafb3b9a72791eeeb810f0bc0472e74c7f4939b20b46c96cb7ebc6838b6a25ef

RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}" GROWTH_R_VERSION=4.6.1
RUN Rscript --vanilla -e 'install.packages("remotes", repos="https://cloud.r-project.org"); remotes::install_version("anthro", version="1.1.0", repos="https://cloud.r-project.org", upgrade="never"); remotes::install_version("jsonlite", version="2.0.0", repos="https://cloud.r-project.org", upgrade="never")'

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
COPY migrations ./migrations
COPY scripts ./scripts
COPY data ./data
RUN python -c "from app.features.growth.anthro_client import calculate; assert calculate([{'row_id':'build','sex':'f','age_days':365,'weight_kg':9.5}])[0]['zwei'] == .49"

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
