This containerized iEEG-recon is adapted from https://github.com/n-sinha/ieeg_recon. It can be run both locally and in [Pennsieve](https://app.pennsieve.io/). 

## To Test Run in Local Docker 
1. Install Docker in your terminal (Guide: https://www.docker.com/get-started/).
2. Set up /data folder locally. Populate the folder with the following structure.  
```
~/data/
├── subRID-XXXX/
│   ├── derivatives/
│   │   └── freesurfer/
│   └── ses-clinical01/
│       └── anat/
│           └── *T1*.nii.gz
│       └── ct/
│           └── *ct*.nii.gz
│       └── ieeg/
│           └── *electrodes*.txt
├── subRID-XXXX/...
├── subRID-XXXX/...
├── subRID-XXXX/...
```

```
docker buildx build --platform linux/amd64 -t ieeg-recon:dev .
docker run --rm -it --platform linux/amd64 \
-v ~/data:/data \ # note the "~/data" should be revised according to how your data is locally stored
--env-file dev.env \
ieeg-recon:dev
```

## To Run in [Pennsieve](https://app.pennsieve.io/)
1. Make sure you have the Pennsieve account and Workspace set up already. 
2. 