#!/bin/bash

# checks whether the latest CloudFormation Linter exists in your environment
if ! command -v cfn-lint &> /dev/null; then
    python -m pip install cfn-lint
else
  latest_version=$(curl --silent "https://api.github.com/repositories/129005655/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
  current_version=$(cfn-lint --version | cut -d ' ' -f 2)
  if [[ $latest_version != $current_version ]]; then
    echo "Updating cfn-lint from $current_version to $latest_version..."
    pip install --upgrade cfn-lint
  fi
fi

# initializing variables
ERRORS=0
WARNINGS=0
ERROR_MESSAGES=()
WARNING_MESSAGES=()

for file in $(find . -name "*.yaml" -o -name "*.yml" -type f); do
  echo "Checking $file..."
  # Run cfn-lint on the file
  output=$(cfn-lint "$file" 2>&1)
  # Parse the output for errors and warnings
  num_errors=$(echo "$output" | grep -c "E[0-9][0-9][0-9][0-9]")
  num_warnings=$(echo "$output" | grep -c "W[0-9][0-9][0-9][0-9]")
  # Add to the running totals
  ERRORS=$((ERRORS + num_errors))
  WARNINGS=$((WARNINGS + num_warnings))
  # Save error and warning messages
  if [ "$num_errors" -gt 0 ]; then
    ERROR_MESSAGES+=("$file:\n$(echo "$output" | grep "E[0-9][0-9][0-9][0-9]" | nl)\n\n")
  fi
  if [ "$num_warnings" -gt 0 ]; then
    WARNING_MESSAGES+=("$file:\n$(echo "$output" | grep "W[0-9][0-9][0-9][0-9]" | nl)\n\n")
  fi
done

# linter summary
echo "----------------------------------------------"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo "----------------------------------------------"

# display the numbered linter warnings and/or errors on demand 
if [ "$ERRORS" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
  if [ "${#ERROR_MESSAGES[@]}" -gt 0 ]; then
    read -r -p "Do you want to view the error messages? [y/N] " response_err
    if [[ "${response_err}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo "----------------------------------------------"
      echo "ERROR MESSAGES:"
      echo "--------------"
      for msg in "${ERROR_MESSAGES[@]}"; do
        printf "$msg"
      done
      echo "----------------------------------------------"
    fi
  fi
  if [ "${#WARNING_MESSAGES[@]}" -gt 0 ]; then
    read -r -p "Do you want to view the warning messages? [y/N] " response_wr
    if [[ "${response_wr}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo "----------------------------------------------"
      echo "WARNING MESSAGES:"
      echo "----------------"
      for msg in "${WARNING_MESSAGES[@]}"; do
        printf "$msg"
      done
      echo "----------------------------------------------"
    fi
  fi
fi

# bottom line (also allows Git Action integration in accordance)
if [ "$ERRORS" -gt 0 ]; then
  echo "---> There are errors that need to be fixed. Please fix them and try again. <---"
  exit 1
else
  echo "---> We're good to go! Feel free to commit your changes. <---"
  exit 0
fi