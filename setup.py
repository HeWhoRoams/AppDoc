"""Setup configuration for AppDoc."""

from setuptools import setup, find_packages
from pathlib import Path

# Read the contents of README file
this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text(encoding='utf-8')

# Read requirements
def read_requirements(filename):
    with open(filename, 'r') as f:
        return [line.strip() for line in f if line.strip() and not line.startswith('#')]

setup(
    name="appdoc",
    version="0.1.0",
    author="AppDoc Team",
    author_email="",
    description="Multi-language documentation analysis tool",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/HeWhoRoams/AppDoc",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Software Development :: Documentation",
        "Topic :: Software Development :: Quality Assurance",
    ],
    keywords="documentation analysis code-metrics python javascript",
    python_requires=">=3.8",
    install_requires=read_requirements("requirements.txt"),
    extras_require={
        "dev": read_requirements("requirements-dev.txt"),
    },
    entry_points={
        "console_scripts": [
            "appdoc=appdoc.cli.main:cli",
        ],
    },
    include_package_data=True,
    zip_safe=False,
)
